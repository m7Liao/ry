package com.ruoyi.attendance.service.impl;

import java.time.*;
import java.util.Date;
import java.util.List;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.attendance.domain.*;
import com.ruoyi.attendance.domain.vo.AttDailyRuleSnapshot;
import com.ruoyi.attendance.mapper.*;
import com.ruoyi.attendance.support.AttDailyCalculator;
import com.ruoyi.common.exception.ServiceException;

/** 共用计算内核；人工入口先校验数据范围，自动入口严格限定任务配置的场所。 */
@Service
public class AttDailyWorker
{
    public static final String AUTO_ACTOR = "attendanceDailyTask";
    private final AttDailyMapper mapper;
    private final AttAutoSettleMapper autoMapper;
    private final AttEmployeeMapper employees;
    private final AttDailyCalculator calculator;
    private final ObjectMapper json;

    public AttDailyWorker(AttDailyMapper mapper, AttAutoSettleMapper autoMapper, AttEmployeeMapper employees,
            AttDailyCalculator calculator, ObjectMapper json)
    {
        this.mapper = mapper; this.autoMapper = autoMapper; this.employees = employees; this.calculator = calculator; this.json = json;
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public boolean create(AttEmployee employee, AttSite site, AttRule rule, LocalDate date, String actor, Instant now, boolean closedOnly)
    {
        AttEmployee locked = employees.lockEmployee(employee.getEmployeeId());
        if (locked == null || !site.getSiteId().equals(locked.getSiteId()) || locked.getHireDate().isAfter(date)
                || (locked.getLeaveDate() != null && locked.getLeaveDate().isBefore(date))) return false;
        if (mapper.selectExistingId(employee.getEmployeeId(), date) != null) return false;
        AttDailyRuleSnapshot config = AttDailyRuleSnapshot.from(rule);
        AttDailyResult result = new AttDailyResult();
        result.setAttendanceDate(date); result.setEmployeeId(employee.getEmployeeId()); result.setUserId(employee.getUserId());
        result.setDeptId(employee.getDeptId()); result.setSiteId(site.getSiteId());
        result.setEmployeeNo(employee.getEmployeeNo()); result.setEmployeeName(employee.getEmployeeName());
        result.setUserName(employee.getUserName()); result.setDeptName(employee.getDeptName()); result.setSiteName(site.getSiteName());
        result.setRuleId(rule.getRuleId()); result.setRuleName(rule.getRuleName()); result.setRuleVersion(rule.getVersion());
        try { result.setRuleSnapshot(json.writeValueAsString(config)); }
        catch (JsonProcessingException e) { throw new ServiceException("规则快照保存失败"); }
        result.setCalculationCount(1);
        calculator.prepare(result, config);
        if (closedOnly && !calculator.isClosed(result, now)) return false;
        calculateRow(result, config, actor, now);
        try { return mapper.insertResult(result) > 0; }
        catch (DuplicateKeyException e)
        {
            if (mapper.selectExistingId(employee.getEmployeeId(), date) == null) throw e;
            return false;
        }
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public boolean autoCreate(Long siteId, Long employeeId, LocalDate date, Instant now)
    {
        // 和人工计算使用相同的员工锁；等待后再次读取当前场所、人员和启用规则。
        if (employees.lockEmployee(employeeId) == null) return false;
        AttSite site = autoMapper.selectSite(siteId);
        AttRule rule = autoMapper.selectRule(siteId);
        if (site == null) throw new ServiceException("配置的场所不存在");
        if (!"0".equals(site.getStatus()) || rule == null || !"0".equals(rule.getStatus())) return false;
        AttEmployee employee = autoMapper.selectEmployee(siteId, employeeId, date);
        if (employee == null) return false;
        return create(employee, site, rule, date, AUTO_ACTOR, now, true);
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public boolean recalculate(Long id, String actor, Instant now, Long expectedSite, boolean pendingOnly)
    {
        AttDailyResult initial = mapper.selectResultById(id);
        if (initial == null) return false;
        if (employees.lockEmployee(initial.getEmployeeId()) == null) throw new ServiceException("关联员工档案不存在");
        AttDailyResult result = mapper.lockResult(id);
        if (result == null || (expectedSite != null && !expectedSite.equals(result.getSiteId()))) return false;
        if (pendingOnly && (!"PENDING".equals(result.getResultStatus()) || !calculator.isClosed(result, now))) return false;
        calculateRow(result, snapshot(result.getRuleSnapshot()), actor, now);
        return mapper.updateCalculation(result) > 0;
    }

    public AttDailyRuleSnapshot snapshot(String value)
    {
        try { return json.readValue(value, AttDailyRuleSnapshot.class); }
        catch (JsonProcessingException e) { throw new ServiceException("保存的规则快照无法读取，请联系管理员"); }
    }

    private void calculateRow(AttDailyResult result, AttDailyRuleSnapshot rule, String actor, Instant now)
    {
        calculator.prepare(result, rule);
        List<AttCheckinRecord> punches = result.getWorkDay() ? mapper.selectPunches(result.getEmployeeId(), result.getSiteId(),
                result.getStartWindowStart(), Date.from(result.getEndWindowEnd().toInstant().plusSeconds(60)), Date.from(now), result.getResultId()) : List.of();
        calculator.calculate(result, rule, punches, now);
        result.setCalculatedBy(actor); result.setCalculatedTime(Date.from(now));
    }
}
