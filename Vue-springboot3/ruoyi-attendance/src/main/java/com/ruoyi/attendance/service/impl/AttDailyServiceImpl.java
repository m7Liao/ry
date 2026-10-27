package com.ruoyi.attendance.service.impl;

import java.time.Instant;
import java.time.LocalDate;
import java.util.Date;
import java.util.List;
import java.util.Map;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.attendance.domain.*;
import com.ruoyi.attendance.domain.dto.AttDailyCalculateRequest;
import com.ruoyi.attendance.domain.vo.AttDailyRuleSnapshot;
import com.ruoyi.attendance.mapper.AttDailyMapper;
import com.ruoyi.attendance.mapper.AttEmployeeMapper;
import com.ruoyi.attendance.service.*;
import com.ruoyi.attendance.support.AttDailyCalculator;
import com.ruoyi.common.annotation.DataScope;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.spring.SpringUtils;

/** 首次计算仅追加；重算只使用服务器保存的规则、身份与场所快照。 */
@Service
public class AttDailyServiceImpl implements IAttDailyService
{
    private final AttDailyMapper mapper;
    private final IAttSiteService siteService;
    private final IAttRuleService ruleService;
    private final AttDailyCalculator calculator;
    private final ObjectMapper json;
    private final AttEmployeeMapper employeeMapper;

    public AttDailyServiceImpl(AttDailyMapper mapper, IAttSiteService siteService, IAttRuleService ruleService,
            AttDailyCalculator calculator, ObjectMapper json, AttEmployeeMapper employeeMapper)
    {
        this.mapper = mapper; this.siteService = siteService; this.ruleService = ruleService;
        this.calculator = calculator; this.json = json;
        this.employeeMapper = employeeMapper;
    }

    @Override
    @DataScope(deptAlias = "r", userAlias = "r")
    public List<AttDailyResult> selectResultList(AttDailyQuery query)
    {
        if (query.getBeginDate() != null && query.getEndDate() != null && query.getBeginDate().isAfter(query.getEndDate()))
            throw new ServiceException("开始日期不能晚于结束日期");
        return mapper.selectResultList(query);
    }

    @Override
    @DataScope(deptAlias = "u", userAlias = "u")
    public List<AttEmployee> selectCandidates(AttDailyQuery query) { return mapper.selectCandidates(query); }

    @Override
    public AttDailyResult getResult(Long resultId)
    {
        AttDailyQuery query = new AttDailyQuery(); query.setResultId(resultId);
        List<AttDailyResult> rows = SpringUtils.getAopProxy(this).selectResultList(query);
        if (rows.isEmpty()) throw new ServiceException("结果不存在或无权访问", 403);
        AttDailyResult result = rows.get(0); result.setRuleConfig(snapshot(result.getRuleSnapshot()));
        return result;
    }

    @Override
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public Map<String, Integer> calculate(AttDailyCalculateRequest request)
    {
        LocalDate date = request.getAttendanceDate();
        if (date.isAfter(LocalDate.now(AttDailyCalculator.ZONE))) throw new ServiceException("不能计算未来日期");
        if (date.getYear() < 1000 || date.getYear() > 9998) throw new ServiceException("考勤日期超出支持范围");
        AttSite site = siteService.getSite(request.getSiteId());
        AttRule ruleQuery = new AttRule(); ruleQuery.setSiteId(site.getSiteId());
        List<AttRule> rules = ruleService.selectRuleList(ruleQuery);
        if (rules.isEmpty() || !"0".equals(rules.get(0).getStatus())) throw new ServiceException("请先为该场所配置并启用考勤规则");
        AttRule rule = rules.get(0);
        AttDailyRuleSnapshot config = AttDailyRuleSnapshot.from(rule);
        String encoded;
        try { encoded = json.writeValueAsString(config); }
        catch (JsonProcessingException e) { throw new ServiceException("规则快照保存失败"); }
        AttDailyQuery query = new AttDailyQuery(); query.setSiteId(site.getSiteId()); query.setAttendanceDate(date);
        List<AttEmployee> candidates = SpringUtils.getAopProxy(this).selectCandidates(query);
        if (candidates.size() > 1000) throw new ServiceException("该场所待计算员工超过1000人，请缩小管理数据范围");
        Instant now = Instant.now(); int created = 0, skipped = 0;
        for (AttEmployee employee : candidates)
        {
            // 同一员工的首次计算和重算串行，防止不同日期抢用同一打卡记录。
            if (employeeMapper.lockEmployee(employee.getEmployeeId()) == null) { skipped++; continue; }
            query.setEmployeeId(employee.getEmployeeId());
            List<AttEmployee> current = SpringUtils.getAopProxy(this).selectCandidates(query);
            if (current.isEmpty()) { skipped++; continue; }
            employee = current.get(0);
            if (mapper.selectExistingId(employee.getEmployeeId(), date) != null) { skipped++; continue; }
            AttDailyResult result = new AttDailyResult();
            result.setAttendanceDate(date); result.setEmployeeId(employee.getEmployeeId()); result.setUserId(employee.getUserId());
            result.setDeptId(employee.getDeptId()); result.setSiteId(site.getSiteId());
            result.setEmployeeNo(employee.getEmployeeNo()); result.setEmployeeName(employee.getEmployeeName());
            result.setUserName(employee.getUserName()); result.setDeptName(employee.getDeptName()); result.setSiteName(site.getSiteName());
            result.setRuleId(rule.getRuleId()); result.setRuleName(rule.getRuleName()); result.setRuleVersion(rule.getVersion());
            result.setRuleSnapshot(encoded); result.setCalculationCount(1);
            runCalculation(result, config, now);
            try { mapper.insertResult(result); created++; }
            catch (DuplicateKeyException e)
            {
                // 同一员工同一日期的并发首次计算只保留先提交的快照，不覆盖。
                if (mapper.selectExistingId(employee.getEmployeeId(), date) == null) throw e;
                skipped++;
            }
        }
        return Map.of("created", created, "skipped", skipped, "candidates", candidates.size());
    }

    @Override
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public int recalculate(List<Long> resultIds)
    {
        int count = 0; Instant now = Instant.now();
        List<Long> ids = resultIds.stream().distinct().sorted().toList();
        // 批量请求先按员工编号统一加锁，再锁结果，保持与首次计算相同的锁顺序。
        List<Long> employees = ids.stream().map(this::getResult).map(AttDailyResult::getEmployeeId).distinct().sorted().toList();
        for (Long employeeId : employees)
        {
            if (employeeMapper.lockEmployee(employeeId) == null) throw new ServiceException("关联员工档案不存在");
        }
        for (Long id : ids)
        {
            getResult(id);
            AttDailyResult result = mapper.lockResult(id);
            if (result == null) throw new ServiceException("结果不存在或无权访问", 403);
            getResult(id);
            runCalculation(result, snapshot(result.getRuleSnapshot()), now);
            count += mapper.updateCalculation(result);
        }
        return count;
    }

    private void runCalculation(AttDailyResult result, AttDailyRuleSnapshot rule, Instant now)
    {
        calculator.prepare(result, rule);
        List<AttCheckinRecord> punches = result.getWorkDay() ? mapper.selectPunches(result.getEmployeeId(), result.getSiteId(),
                result.getStartWindowStart(), Date.from(result.getEndWindowEnd().toInstant().plusSeconds(60)), Date.from(now), result.getResultId()) : List.of();
        calculator.calculate(result, rule, punches, now);
        result.setCalculatedBy(SecurityUtils.getUsername()); result.setCalculatedTime(Date.from(now));
    }

    private AttDailyRuleSnapshot snapshot(String value)
    {
        try { return json.readValue(value, AttDailyRuleSnapshot.class); }
        catch (JsonProcessingException e) { throw new ServiceException("保存的规则快照无法读取，请联系管理员"); }
    }
}
