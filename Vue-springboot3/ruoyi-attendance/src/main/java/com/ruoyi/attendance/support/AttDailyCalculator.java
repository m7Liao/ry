package com.ruoyi.attendance.support;

import java.time.*;
import java.time.temporal.ChronoUnit;
import java.util.Arrays;
import java.util.Comparator;
import java.util.Date;
import java.util.List;
import org.springframework.stereotype.Component;
import com.ruoyi.attendance.domain.*;
import com.ruoyi.attendance.domain.vo.AttDailyRuleSnapshot;
import com.ruoyi.common.exception.ServiceException;

/** 固定班次 V1：分钟精度、窗口含结束分钟、双窗口、工时不用于加班结算。 */
@Component
public class AttDailyCalculator
{
    public static final ZoneId ZONE = ZoneId.of("Asia/Shanghai");

    public void prepare(AttDailyResult result, AttDailyRuleSnapshot rule)
    {
        if (!"FIXED_V1".equals(rule.algorithm())) throw new ServiceException("该结果的计算版本暂不受支持");
        LocalDate date = result.getAttendanceDate();
        LocalDateTime start = date.atTime(LocalTime.parse(rule.startTime()));
        LocalDateTime end = date.plusDays("1".equals(rule.endNextDay()) ? 1 : 0).atTime(LocalTime.parse(rule.endTime()));
        result.setScheduledStart(time(start)); result.setScheduledEnd(time(end));
        result.setStartWindowStart(time(start.minusMinutes(rule.startBeforeMinutes())));
        result.setStartWindowEnd(time(start.plusMinutes(rule.startAfterMinutes())));
        result.setEndWindowStart(time(end.minusMinutes(rule.endBeforeMinutes())));
        result.setEndWindowEnd(time(end.plusMinutes(rule.endAfterMinutes())));
        boolean working = working(rule, date);
        result.setWorkDay(working);
        result.setPlannedWorkMinutes(working ? (int) Duration.between(start, end).toMinutes() - rule.restMinutes() : 0);
        // 连续工作日不能共用一段打卡窗口，否则一条记录可能被用于两个班次。
        if (working && ((working(rule, date.plusDays(1)) && end.plusMinutes(rule.endAfterMinutes() + 1L).isAfter(start.plusDays(1).minusMinutes(rule.startBeforeMinutes())))
                || (working(rule, date.minusDays(1)) && end.minusDays(1).plusMinutes(rule.endAfterMinutes() + 1L).isAfter(start.minusMinutes(rule.startBeforeMinutes())))))
        {
            throw new ServiceException("相邻工作日的打卡窗口过近或重叠，请缩短窗口或班次后再计算");
        }
    }

    public void calculate(AttDailyResult result, AttDailyRuleSnapshot rule, List<AttCheckinRecord> punches, Instant now)
    {
        prepare(result, rule);
        result.setInRecordId(null); result.setOutRecordId(null);
        result.setInTime(null); result.setOutTime(null);
        result.setMissingIn(false); result.setMissingOut(false);
        result.setLateMinutes(0); result.setEarlyMinutes(0); result.setWorkMinutes(null);
        if (!result.getWorkDay())
        {
            result.setResultStatus("REST"); result.setWorkMinutes(0); return;
        }
        Comparator<AttCheckinRecord> order = Comparator.comparing(AttCheckinRecord::getCheckinTime).thenComparing(AttCheckinRecord::getRecordId);
        AttCheckinRecord in = punches.stream().filter(p -> within(p, result.getStartWindowStart(), result.getStartWindowEnd(), now)).min(order).orElse(null);
        AttCheckinRecord out = punches.stream().filter(p -> within(p, result.getEndWindowStart(), result.getEndWindowEnd(), now)).max(order).orElse(null);
        LocalDateTime start = local(result.getScheduledStart()), end = local(result.getScheduledEnd());
        if (in != null)
        {
            result.setInRecordId(in.getRecordId()); result.setInTime(in.getCheckinTime());
            LocalDateTime actual = local(in.getCheckinTime()).truncatedTo(ChronoUnit.MINUTES);
            if (actual.isAfter(start.plusMinutes(rule.lateGraceMinutes()))) result.setLateMinutes((int) Duration.between(start, actual).toMinutes());
        }
        if (out != null)
        {
            result.setOutRecordId(out.getRecordId()); result.setOutTime(out.getCheckinTime());
            LocalDateTime actual = local(out.getCheckinTime()).truncatedTo(ChronoUnit.MINUTES);
            if (actual.isBefore(end.minusMinutes(rule.earlyGraceMinutes()))) result.setEarlyMinutes((int) Duration.between(actual, end).toMinutes());
        }
        boolean inClosed = !now.isBefore(result.getStartWindowEnd().toInstant().plus(1, ChronoUnit.MINUTES));
        boolean outClosed = !now.isBefore(result.getEndWindowEnd().toInstant().plus(1, ChronoUnit.MINUTES));
        result.setMissingIn(in == null && inClosed); result.setMissingOut(out == null && outClosed);
        if (!inClosed || !outClosed) { result.setResultStatus("PENDING"); return; }
        if (in != null && out != null)
        {
            long minutes = Duration.between(local(in.getCheckinTime()).truncatedTo(ChronoUnit.MINUTES), local(out.getCheckinTime()).truncatedTo(ChronoUnit.MINUTES)).toMinutes();
            result.setWorkMinutes((int) Math.max(0, minutes - rule.restMinutes()));
        }
        boolean abnormal = result.getMissingIn() || result.getMissingOut() || result.getLateMinutes() > 0 || result.getEarlyMinutes() > 0;
        result.setResultStatus(abnormal ? "ABNORMAL" : "NORMAL");
    }

    private boolean working(AttDailyRuleSnapshot rule, LocalDate date)
    {
        return Arrays.asList(rule.workDays().split(",")).contains(String.valueOf(date.getDayOfWeek().getValue()));
    }

    /** 包含窗口结束的整分钟；休息日到次日零时才允许自动落账。 */
    public boolean isClosed(AttDailyResult result, Instant now)
    {
        if (!result.getWorkDay()) return !now.isBefore(result.getAttendanceDate().plusDays(1).atStartOfDay(ZONE).toInstant());
        return !now.isBefore(result.getStartWindowEnd().toInstant().plusSeconds(60))
                && !now.isBefore(result.getEndWindowEnd().toInstant().plusSeconds(60));
    }

    private boolean within(AttCheckinRecord punch, Date from, Date end, Instant now)
    {
        Instant time = punch.getCheckinTime().toInstant();
        return !time.isBefore(from.toInstant()) && time.isBefore(end.toInstant().plus(1, ChronoUnit.MINUTES)) && !time.isAfter(now);
    }

    private Date time(LocalDateTime value) { return Date.from(value.atZone(ZONE).toInstant()); }
    private LocalDateTime local(Date value) { return value.toInstant().atZone(ZONE).toLocalDateTime(); }
}
