package com.ruoyi.attendance.service.impl;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.attendance.domain.*;
import com.ruoyi.attendance.domain.dto.AttDailyCalculateRequest;
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
    private final AttDailyWorker worker;
    private final AttEmployeeMapper employeeMapper;

    public AttDailyServiceImpl(AttDailyMapper mapper, IAttSiteService siteService, IAttRuleService ruleService,
            AttDailyWorker worker, AttEmployeeMapper employeeMapper)
    {
        this.mapper = mapper; this.siteService = siteService; this.ruleService = ruleService;
        this.worker = worker;
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
    public List<AttDailyResult> selectMyResultList(AttDailyQuery query)
    {
        if (query.getBeginDate() == null && query.getEndDate() == null)
        {
            query.setEndDate(LocalDate.now(AttDailyCalculator.ZONE)); query.setBeginDate(query.getEndDate().minusDays(29));
        }
        if (query.getBeginDate() == null || query.getEndDate() == null) throw new ServiceException("请同时提供开始日期和结束日期");
        long days = java.time.temporal.ChronoUnit.DAYS.between(query.getBeginDate(), query.getEndDate());
        if (days < 0 || days > 92) throw new ServiceException("查询日期需按先后顺序，且每次不超过93天");
        return mapper.selectMyResultList(query, SecurityUtils.getUserId());
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
        AttDailyResult result = rows.get(0); result.setRuleConfig(worker.snapshot(result.getRuleSnapshot()));
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
            if (worker.create(employee, site, rule, date, SecurityUtils.getUsername(), now, false)) created++;
            else skipped++;
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
            if (worker.recalculate(id, SecurityUtils.getUsername(), now, null, false)) count++;
        }
        return count;
    }

}
