package com.ruoyi.attendance;

import java.time.*;
import java.util.*;
import com.ruoyi.attendance.domain.*;
import com.ruoyi.attendance.domain.vo.AttDailyRuleSnapshot;
import com.ruoyi.attendance.support.AttDailyCalculator;
import com.ruoyi.common.exception.ServiceException;

/** 无额外测试依赖的固定时钟边界测试，运行方式见 test/verify-daily-calculator.ps1。 */
public class AttDailyCalculatorTest
{
    private static final AttDailyCalculator CALC = new AttDailyCalculator();
    private static final LocalDate DAY = LocalDate.of(2026, 10, 19);
    private static int checks;

    public static void main(String[] args)
    {
        AttDailyRuleSnapshot day = config("09:00", "18:00", "0", "1,2,3,4,5", 5, 5, 60);
        AttDailyResult normal = run(day, DAY, "2026-10-19T21:00:00", punch(4, "2026-10-19T18:10:00"),
                punch(3, "2026-10-19T12:00:00"), punch(2, "2026-10-19T08:55:00"), punch(1, "2026-10-19T08:50:00"));
        check("NORMAL".equals(normal.getResultStatus()) && normal.getInRecordId() == 1 && normal.getOutRecordId() == 4 && normal.getWorkMinutes() == 500, "earliest/latest window matching and hours");
        AttDailyResult boundary = run(day, DAY, "2026-10-19T21:00:00", punch(1, "2026-10-19T09:05:59"), punch(2, "2026-10-19T17:55:59"));
        check(boundary.getLateMinutes() == 0 && boundary.getEarlyMinutes() == 0 && boundary.getWorkMinutes() == 470, "inclusive grace minute");
        AttDailyResult late = run(day, DAY, "2026-10-19T21:00:00", punch(1, "2026-10-19T09:06:00"), punch(2, "2026-10-19T17:54:00"));
        check("ABNORMAL".equals(late.getResultStatus()) && late.getLateMinutes() == 6 && late.getEarlyMinutes() == 6 && late.getWorkMinutes() == 468, "full abnormal minutes after grace");
        AttDailyResult empty = run(day, DAY, "2026-10-19T21:00:00");
        check(empty.getMissingIn() && empty.getMissingOut() && empty.getWorkMinutes() == null, "both missing is unknown hours");
        AttDailyResult one = run(day, DAY, "2026-10-19T21:00:00", punch(1, "2026-10-19T09:00:00"));
        check(!one.getMissingIn() && one.getMissingOut() && one.getWorkMinutes() == null, "one missing is unknown hours");
        AttDailyResult edge = run(day, DAY, "2026-10-19T21:00:00", punch(1, "2026-10-19T10:00:59.999"), punch(2, "2026-10-19T20:00:59.999"));
        check(!edge.getMissingIn() && !edge.getMissingOut(), "window includes full final minute");
        AttDailyResult outside = run(day, DAY, "2026-10-19T21:00:00", punch(1, "2026-10-19T10:01:00"), punch(2, "2026-10-19T20:01:00"));
        check(outside.getMissingIn() && outside.getMissingOut(), "outside windows ignored");
        AttDailyResult pending = run(day, DAY, "2026-10-19T20:00:59.999");
        check("PENDING".equals(pending.getResultStatus()) && pending.getMissingIn() && !pending.getMissingOut() && pending.getWorkMinutes() == null, "no premature missing at final minute");
        AttDailyResult closed = run(day, DAY, "2026-10-19T20:01:00");
        check("ABNORMAL".equals(closed.getResultStatus()) && closed.getMissingOut(), "window closes at next minute");
        AttDailyResult future = run(day, DAY, "2026-10-19T09:00:00", punch(1, "2026-10-19T09:00:00"), punch(2, "2026-10-19T18:00:00"));
        check(future.getOutRecordId() == null && "PENDING".equals(future.getResultStatus()), "future punches ignored");
        AttDailyRuleSnapshot night = config("22:00", "06:00", "1", "1,2,3,4,5", 5, 0, 30);
        AttDailyResult overnight = run(night, DAY, "2026-10-20T09:00:00", punch(1, "2026-10-19T22:10:00"), punch(2, "2026-10-20T05:58:00"));
        check(overnight.getAttendanceDate().equals(DAY) && overnight.getLateMinutes() == 10 && overnight.getEarlyMinutes() == 2 && overnight.getWorkMinutes() == 438 && overnight.getPlannedWorkMinutes() == 450, "overnight date and elapsed hours");
        AttDailyResult rest = run(day, DAY.minusDays(1), "2026-10-19T21:00:00", punch(1, "2026-10-18T09:00:00"));
        check("REST".equals(rest.getResultStatus()) && rest.getWorkMinutes() == 0 && rest.getPlannedWorkMinutes() == 0 && !rest.getMissingIn(), "rest day has no missing or overtime");
        AttDailyResult zero = run(config("09:00", "18:00", "0", "1", 5, 0, 500), DAY, "2026-10-19T21:00:00", punch(1, "2026-10-19T10:00:00"), punch(2, "2026-10-19T17:00:00"));
        check(zero.getWorkMinutes() == 0, "hours floor at zero");
        AttDailyResult ties = run(day, DAY, "2026-10-19T21:00:00", punch(5, "2026-10-19T09:00:00"), punch(1, "2026-10-19T09:00:00"), punch(6, "2026-10-19T18:00:00"), punch(2, "2026-10-19T18:00:00"));
        check(ties.getInRecordId() == 1 && ties.getOutRecordId() == 6, "deterministic equal-time selection");
        try { run(config("09:00", "09:00", "1", "1,2,3,4,5,6,7", 0, 0, 0), DAY, "2026-10-21T21:00:00"); throw new AssertionError("overlapping neighboring shifts accepted"); }
        catch (ServiceException expected) { checks++; }
        System.out.println("PASS: " + checks + " fixed-clock calculator cases");
    }

    private static AttDailyRuleSnapshot config(String start, String end, String next, String days, int late, int early, int rest)
    {
        return new AttDailyRuleSnapshot("FIXED_V1", 1L, "test", 0, days, start, end, next, late, early, 60, 60, 60, 120, rest);
    }
    private static AttDailyResult run(AttDailyRuleSnapshot rule, LocalDate day, String now, AttCheckinRecord... punches)
    {
        AttDailyResult result = new AttDailyResult(); result.setAttendanceDate(day);
        CALC.calculate(result, rule, Arrays.asList(punches), instant(now)); return result;
    }
    private static AttCheckinRecord punch(long id, String time)
    {
        AttCheckinRecord record = new AttCheckinRecord(); record.setRecordId(id); record.setCheckinTime(Date.from(instant(time))); return record;
    }
    private static Instant instant(String value) { return LocalDateTime.parse(value).atZone(AttDailyCalculator.ZONE).toInstant(); }
    private static void check(boolean condition, String message) { if (!condition) throw new AssertionError(message); checks++; }
}
