package com.ruoyi.attendance.domain.vo;

import java.time.LocalDate;
import java.util.Date;
import com.fasterxml.jackson.annotation.*;

/** 统计结果：跨日按人次，employeeCount 单独表示去重员工数。 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public class AttDashboardMetrics
{
    private long totalCount;
    private long employeeCount;
    private long settledCount;
    private long normalCount;
    private long abnormalCount;
    private long missingCount;
    private long pendingCount;
    private long restCount;
    private long lateCount;
    private long earlyCount;
    private long missingInCount;
    private long missingOutCount;
    @JsonFormat(pattern = "yyyy-MM-dd")
    private LocalDate attendanceDate;
    private Long siteId;
    private String siteName;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "GMT+8")
    private Date lastCalculatedTime;
    public long getTotalCount() { return totalCount; }
    public void setTotalCount(long totalCount) { this.totalCount = totalCount; }
    public long getEmployeeCount() { return employeeCount; }
    public void setEmployeeCount(long employeeCount) { this.employeeCount = employeeCount; }
    public long getSettledCount() { return settledCount; }
    public void setSettledCount(long settledCount) { this.settledCount = settledCount; }
    public long getNormalCount() { return normalCount; }
    public void setNormalCount(long normalCount) { this.normalCount = normalCount; }
    public long getAbnormalCount() { return abnormalCount; }
    public void setAbnormalCount(long abnormalCount) { this.abnormalCount = abnormalCount; }
    public long getMissingCount() { return missingCount; }
    public void setMissingCount(long missingCount) { this.missingCount = missingCount; }
    public long getPendingCount() { return pendingCount; }
    public void setPendingCount(long pendingCount) { this.pendingCount = pendingCount; }
    public long getRestCount() { return restCount; }
    public void setRestCount(long restCount) { this.restCount = restCount; }
    public long getLateCount() { return lateCount; }
    public void setLateCount(long lateCount) { this.lateCount = lateCount; }
    public long getEarlyCount() { return earlyCount; }
    public void setEarlyCount(long earlyCount) { this.earlyCount = earlyCount; }
    public long getMissingInCount() { return missingInCount; }
    public void setMissingInCount(long missingInCount) { this.missingInCount = missingInCount; }
    public long getMissingOutCount() { return missingOutCount; }
    public void setMissingOutCount(long missingOutCount) { this.missingOutCount = missingOutCount; }
    public LocalDate getAttendanceDate() { return attendanceDate; }
    public void setAttendanceDate(LocalDate attendanceDate) { this.attendanceDate = attendanceDate; }
    public Long getSiteId() { return siteId; }
    public void setSiteId(Long siteId) { this.siteId = siteId; }
    public String getSiteName() { return siteName; }
    public void setSiteName(String siteName) { this.siteName = siteName; }
    public Date getLastCalculatedTime() { return lastCalculatedTime; }
    public void setLastCalculatedTime(Date lastCalculatedTime) { this.lastCalculatedTime = lastCalculatedTime; }
}
