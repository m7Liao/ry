package com.ruoyi.attendance;

import java.time.*;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import com.ruoyi.attendance.domain.AttDailyResult;
import com.ruoyi.attendance.domain.vo.AttDailyRuleSnapshot;
import com.ruoyi.attendance.support.*;
import com.ruoyi.common.core.domain.TaskExecutionResult;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.quartz.domain.SysJob;
import com.ruoyi.quartz.util.JobInvokeUtil;
import org.springframework.dao.CannotAcquireLockException;

public class AttAutoSettleTest
{
    public static class Probe
    {
        public void oldVoidTask() {}
        public TaskExecutionResult report() { return new TaskExecutionResult(false, "partial failure"); }
        public void broken() { throw new ServiceException("fixture-error"); }
    }
    public static void main(String[] args) throws Exception
    {
        check(AttAutoSettleSupport.siteIds(" 2,1,2 ").equals(List.of(1L,2L)), "canonical explicit scope");
        for (String bad : List.of("", "*", "ALL", "0", "-1", "1,", "9223372036854775808"))
        {
            try { AttAutoSettleSupport.siteIds(bad); throw new AssertionError("unsafe scope accepted: " + bad); }
            catch (ServiceException expected) {}
        }
        AtomicInteger attempts = new AtomicInteger(), retries = new AtomicInteger();
        String result = AttAutoSettleSupport.retry(() -> { if (attempts.incrementAndGet() < 3) throw new CannotAcquireLockException("test"); return "ok"; }, ignored -> retries.incrementAndGet());
        check(result.equals("ok") && attempts.get()==3 && retries.get()==2, "retry transient failure in three attempts");
        attempts.set(0);
        try { AttAutoSettleSupport.retry(() -> { attempts.incrementAndGet(); throw new ServiceException("invalid config"); }, ignored -> {}); throw new AssertionError("business error swallowed"); }
        catch (ServiceException expected) { check(attempts.get()==1, "business error not retried"); }
        attempts.set(0);
        try { AttAutoSettleSupport.retry(() -> { attempts.incrementAndGet(); throw new CannotAcquireLockException("test"); }, ignored -> {}); throw new AssertionError("exhausted retry swallowed"); }
        catch (CannotAcquireLockException expected) { check(attempts.get()==3, "retry has finite upper bound"); }
        AttDailyCalculator calculator = new AttDailyCalculator();
        AttDailyResult night = new AttDailyResult(); night.setAttendanceDate(LocalDate.of(2026,10,19));
        calculator.prepare(night, new AttDailyRuleSnapshot("FIXED_V1",1L,"night",0,"1,2,3,4,5","22:00","06:00","1",5,0,60,60,60,120,30));
        check(!calculator.isClosed(night, instant("2026-10-20T08:00:59.999")), "night waits for full final minute");
        check(calculator.isClosed(night, instant("2026-10-20T08:01:00")), "night settles after window closes");
        AttDailyResult rest = new AttDailyResult(); rest.setAttendanceDate(LocalDate.of(2026,10,18)); rest.setWorkDay(false);
        check(!calculator.isClosed(rest, instant("2026-10-18T23:59:59")) && calculator.isClosed(rest, instant("2026-10-19T00:00:00")), "rest day waits until following midnight");
        SysJob job = new SysJob(); String prefix=Probe.class.getName()+".";
        job.setInvokeTarget(prefix+"oldVoidTask()"); check(JobInvokeUtil.invokeMethod(job)==null, "old void tasks remain compatible");
        job.setInvokeTarget(prefix+"report()"); check(JobInvokeUtil.invokeMethod(job) instanceof TaskExecutionResult r && !r.success(), "explicit partial-failure report retained");
        job.setInvokeTarget(prefix+"broken()");
        try { JobInvokeUtil.invokeMethod(job); throw new AssertionError("task exception swallowed"); }
        catch (ServiceException expected) { check("fixture-error".equals(expected.getMessage()), "task exception cause preserved"); }
        System.out.println("PASS: explicit scope validation, bounded transient retry, nightly/rest closure, void-task compatibility and task reports");
    }
    private static Instant instant(String value) { return LocalDateTime.parse(value).atZone(AttDailyCalculator.ZONE).toInstant(); }
    private static void check(boolean condition, String message) { if (!condition) throw new AssertionError(message); }
}
