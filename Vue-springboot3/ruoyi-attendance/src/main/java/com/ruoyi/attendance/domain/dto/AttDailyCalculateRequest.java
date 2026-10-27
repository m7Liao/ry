package com.ruoyi.attendance.domain.dto;

import java.time.LocalDate;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public class AttDailyCalculateRequest
{
    @NotNull(message = "请选择办公场所") @Positive
    private Long siteId;
    @NotNull(message = "请选择考勤日期")
    private LocalDate attendanceDate;
    public Long getSiteId() { return siteId; }
    public void setSiteId(Long siteId) { this.siteId = siteId; }
    public LocalDate getAttendanceDate() { return attendanceDate; }
    public void setAttendanceDate(LocalDate attendanceDate) { this.attendanceDate = attendanceDate; }
}
