package com.ruoyi.attendance.domain.vo;

import java.time.LocalDate;
import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.attendance.domain.AttDailyResult;

/** 员工端仅返回本人查看所需字段，不包含账号、部门或规则内部快照。 */
public record AttMyDailyResult(Long resultId, LocalDate attendanceDate, String siteName, String resultStatus,
        @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "GMT+8") Date scheduledStart,
        @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "GMT+8") Date scheduledEnd,
        @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "GMT+8") Date inTime,
        @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "GMT+8") Date outTime,
        Boolean missingIn, Boolean missingOut, Integer lateMinutes, Integer earlyMinutes,
        Integer plannedWorkMinutes, Integer workMinutes,
        @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "GMT+8") Date calculatedTime)
{
    public static AttMyDailyResult from(AttDailyResult row)
    {
        return new AttMyDailyResult(row.getResultId(), row.getAttendanceDate(), row.getSiteName(), row.getResultStatus(),
                row.getScheduledStart(), row.getScheduledEnd(), row.getInTime(), row.getOutTime(), row.getMissingIn(),
                row.getMissingOut(), row.getLateMinutes(), row.getEarlyMinutes(), row.getPlannedWorkMinutes(),
                row.getWorkMinutes(), row.getCalculatedTime());
    }
}
