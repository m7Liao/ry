package com.ruoyi.attendance.domain;

import java.time.LocalDate;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import org.springframework.format.annotation.DateTimeFormat;
import com.ruoyi.common.core.domain.BaseEntity;

/** 每日结果查询及内部员工范围查询。 */
public class AttDailyQuery extends BaseEntity
{
    private Long resultId;
    private Long employeeId;
    @Positive
    private Long siteId;
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate attendanceDate;
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate beginDate;
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate endDate;
    private String employeeNo;
    private String employeeName;
    @Pattern(regexp = "^$|PENDING|REST|NORMAL|ABNORMAL", message = "结果状态不正确")
    private String resultStatus;
    @Pattern(regexp = "^$|LATE|EARLY|MISSING_IN|MISSING_OUT", message = "异常类型不正确")
    private String abnormalType;
    @Pattern(regexp = "^$|SETTLED|MISSING", message = "统计范围不正确")
    private String resultGroup;
    public Long getResultId() { return resultId; }
    public void setResultId(Long resultId) { this.resultId = resultId; }
    public Long getEmployeeId() { return employeeId; }
    public void setEmployeeId(Long employeeId) { this.employeeId = employeeId; }
    public Long getSiteId() { return siteId; }
    public void setSiteId(Long siteId) { this.siteId = siteId; }
    public LocalDate getAttendanceDate() { return attendanceDate; }
    public void setAttendanceDate(LocalDate attendanceDate) { this.attendanceDate = attendanceDate; }
    public LocalDate getBeginDate() { return beginDate; }
    public void setBeginDate(LocalDate beginDate) { this.beginDate = beginDate; }
    public LocalDate getEndDate() { return endDate; }
    public void setEndDate(LocalDate endDate) { this.endDate = endDate; }
    public String getEmployeeNo() { return employeeNo; }
    public void setEmployeeNo(String employeeNo) { this.employeeNo = employeeNo; }
    public String getEmployeeName() { return employeeName; }
    public void setEmployeeName(String employeeName) { this.employeeName = employeeName; }
    public String getResultStatus() { return resultStatus; }
    public void setResultStatus(String resultStatus) { this.resultStatus = resultStatus; }
    public String getAbnormalType() { return abnormalType; }
    public void setAbnormalType(String abnormalType) { this.abnormalType = abnormalType; }
    public String getResultGroup() { return resultGroup; }
    public void setResultGroup(String resultGroup) { this.resultGroup = resultGroup; }
}
