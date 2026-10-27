package com.ruoyi.attendance.service.impl;

import java.time.*;
import java.util.Date;
import java.util.List;
import java.util.function.Supplier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import com.ruoyi.attendance.domain.*;
import com.ruoyi.attendance.domain.vo.AttDailyRuleSnapshot;
import com.ruoyi.attendance.mapper.AttAutoSettleMapper;
import com.ruoyi.attendance.support.*;
import com.ruoyi.common.core.domain.TaskExecutionResult;
import com.ruoyi.common.exception.ServiceException;

/** 自动任务按单员工/单结果事务处理；一个失败不回滚其他员工，后续周期可续跑。 */
@Service
public class AttAutoSettleService
{
    private static final Logger LOG = LoggerFactory.getLogger(AttAutoSettleService.class);
    private final AttAutoSettleMapper mapper;
    private final AttDailyWorker worker;
    private final AttDailyCalculator calculator;
    public AttAutoSettleService(AttAutoSettleMapper mapper, AttDailyWorker worker, AttDailyCalculator calculator)
    { this.mapper = mapper; this.worker = worker; this.calculator = calculator; }

    public TaskExecutionResult settle(String scope)
    {
        List<Long> sites = AttAutoSettleSupport.siteIds(scope);
        Instant now = Instant.now(); LocalDate today = now.atZone(AttDailyCalculator.ZONE).toLocalDate();
        Totals totals = new Totals();
        for (Long siteId : sites)
        {
            try
            {
                AttSite site = mapper.selectSite(siteId);
                if (site == null) throw new ServiceException("配置的场所不存在");
                List<Long> pending = mapper.selectClosedPending(siteId, Date.from(now));
                for (Long resultId : pending)
                    attempt(totals, "场所" + siteId + "结果" + resultId, false,
                            () -> worker.recalculate(resultId, AttDailyWorker.AUTO_ACTOR, now, siteId, true));
                AttRule rule = mapper.selectRule(siteId);
                if (!"0".equals(site.getStatus()) || rule == null || !"0".equals(rule.getStatus())) { totals.skipped++; continue; }
                for (int daysAgo = 2; daysAgo >= 0; daysAgo--)
                {
                    LocalDate day = today.minusDays(daysAgo);
                    try
                    {
                        AttDailyResult probe = new AttDailyResult(); probe.setAttendanceDate(day);
                        calculator.prepare(probe, AttDailyRuleSnapshot.from(rule));
                        if (!calculator.isClosed(probe, now)) { totals.skipped++; continue; }
                        List<Long> employees = mapper.selectMissingEmployees(siteId, day);
                        if (employees.size() > 1000) throw new ServiceException("单场所单日待生成员工超过1000，请拆分场所或使用人工补算");
                        for (Long employeeId : employees)
                            attempt(totals, "场所" + siteId + "日期" + day + "员工" + employeeId, true,
                                    () -> worker.autoCreate(siteId, employeeId, day, now));
                    }
                    catch (RuntimeException e) { totals.failure("场所" + siteId + "日期" + day, e); }
                }
            }
            catch (RuntimeException e) { totals.failure("场所" + siteId, e); }
        }
        String message = "场所" + sites.size() + "，新增" + totals.created + "，结算" + totals.settled
                + "，跳过" + totals.skipped + "，失败" + totals.failed + "，重试" + totals.retried
                + (totals.firstError == null ? "" : "；" + totals.firstError);
        LOG.info("自动日结：{}", message);
        return new TaskExecutionResult(totals.failed == 0, message);
    }

    private void attempt(Totals totals, String label, boolean creating, Supplier<Boolean> action)
    {
        try
        {
            boolean changed = AttAutoSettleSupport.retry(action, ignored -> totals.retried++);
            if (!changed) totals.skipped++;
            else if (creating) totals.created++;
            else totals.settled++;
        }
        catch (RuntimeException e) { totals.failure(label, e); }
    }

    private static class Totals
    {
        int created, settled, skipped, failed, retried;
        String firstError;
        void failure(String label, RuntimeException error)
        {
            failed++;
            String reason = error instanceof ServiceException ? error.getMessage() : "数据访问或规则参数异常";
            if (firstError == null) firstError = label + "：" + reason;
            LOG.warn("自动日结失败：{}，{}", label, reason);
        }
    }
}
