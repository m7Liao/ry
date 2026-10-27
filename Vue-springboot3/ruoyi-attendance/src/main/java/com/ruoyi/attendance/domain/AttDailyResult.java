package com.ruoyi.attendance.domain;

import java.time.LocalDate;
import java.util.Date;
import com.fasterxml.jackson.annotation.*;
import com.ruoyi.attendance.domain.vo.AttDailyRuleSnapshot;
import com.ruoyi.common.core.domain.BaseEntity;

/** 每日考勤结果。身份和规则快照首次创建后不被重新计算改写。 */
public class AttDailyResult extends BaseEntity
{
    private static final long serialVersionUID = 1L;
    private Long resultId;
    @JsonFormat(pattern = "yyyy-MM-dd")
    private LocalDate attendanceDate;
    private Long employeeId;
    private Long userId;
    private Long deptId;
    private Long siteId;
    private String employeeNo;
    private String employeeName;
    private String userName;
    private String deptName;
    private String siteName;
    private Long ruleId;
    private String ruleName;
    private Integer ruleVersion;
    @JsonIgnore
    private String ruleSnapshot;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "GMT+8")
    private Date scheduledStart;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "GMT+8")
    private Date scheduledEnd;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "GMT+8")
    private Date startWindowStart;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "GMT+8")
    private Date startWindowEnd;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "GMT+8")
    private Date endWindowStart;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "GMT+8")
    private Date endWindowEnd;
    private Long inRecordId;
    private Long outRecordId;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "GMT+8")
    private Date inTime;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "GMT+8")
    private Date outTime;
    private Boolean workDay;
    private String resultStatus;
    private Boolean missingIn;
    private Boolean missingOut;
    private Integer lateMinutes;
    private Integer earlyMinutes;
    private Integer plannedWorkMinutes;
    private Integer workMinutes;
    private Integer calculationCount;
    private String calculatedBy;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "GMT+8")
    private Date calculatedTime;
    @JsonInclude(JsonInclude.Include.NON_NULL)
    private AttDailyRuleSnapshot ruleConfig;
    public Long getResultId() { return resultId; }
    public void setResultId(Long resultId) { this.resultId = resultId; }
    public LocalDate getAttendanceDate() { return attendanceDate; }
    public void setAttendanceDate(LocalDate attendanceDate) { this.attendanceDate = attendanceDate; }
    public Long getEmployeeId() { return employeeId; }
    public void setEmployeeId(Long employeeId) { this.employeeId = employeeId; }
    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public Long getDeptId() { return deptId; }
    public void setDeptId(Long deptId) { this.deptId = deptId; }
    public Long getSiteId() { return siteId; }
    public void setSiteId(Long siteId) { this.siteId = siteId; }
    public String getEmployeeNo() { return employeeNo; }
    public void setEmployeeNo(String employeeNo) { this.employeeNo = employeeNo; }
    public String getEmployeeName() { return employeeName; }
    public void setEmployeeName(String employeeName) { this.employeeName = employeeName; }
    public String getUserName() { return userName; }
    public void setUserName(String userName) { this.userName = userName; }
    public String getDeptName() { return deptName; }
    public void setDeptName(String deptName) { this.deptName = deptName; }
    public String getSiteName() { return siteName; }
    public void setSiteName(String siteName) { this.siteName = siteName; }
    public Long getRuleId() { return ruleId; }
    public void setRuleId(Long ruleId) { this.ruleId = ruleId; }
    public String getRuleName() { return ruleName; }
    public void setRuleName(String ruleName) { this.ruleName = ruleName; }
    public Integer getRuleVersion() { return ruleVersion; }
    public void setRuleVersion(Integer ruleVersion) { this.ruleVersion = ruleVersion; }
    public String getRuleSnapshot() { return ruleSnapshot; }
    public void setRuleSnapshot(String ruleSnapshot) { this.ruleSnapshot = ruleSnapshot; }
    public Date getScheduledStart() { return scheduledStart; }
    public void setScheduledStart(Date scheduledStart) { this.scheduledStart = scheduledStart; }
    public Date getScheduledEnd() { return scheduledEnd; }
    public void setScheduledEnd(Date scheduledEnd) { this.scheduledEnd = scheduledEnd; }
    public Date getStartWindowStart() { return startWindowStart; }
    public void setStartWindowStart(Date startWindowStart) { this.startWindowStart = startWindowStart; }
    public Date getStartWindowEnd() { return startWindowEnd; }
    public void setStartWindowEnd(Date startWindowEnd) { this.startWindowEnd = startWindowEnd; }
    public Date getEndWindowStart() { return endWindowStart; }
    public void setEndWindowStart(Date endWindowStart) { this.endWindowStart = endWindowStart; }
    public Date getEndWindowEnd() { return endWindowEnd; }
    public void setEndWindowEnd(Date endWindowEnd) { this.endWindowEnd = endWindowEnd; }
    public Long getInRecordId() { return inRecordId; }
    public void setInRecordId(Long inRecordId) { this.inRecordId = inRecordId; }
    public Long getOutRecordId() { return outRecordId; }
    public void setOutRecordId(Long outRecordId) { this.outRecordId = outRecordId; }
    public Date getInTime() { return inTime; }
    public void setInTime(Date inTime) { this.inTime = inTime; }
    public Date getOutTime() { return outTime; }
    public void setOutTime(Date outTime) { this.outTime = outTime; }
    public Boolean getWorkDay() { return workDay; }
    public void setWorkDay(Boolean workDay) { this.workDay = workDay; }
    public String getResultStatus() { return resultStatus; }
    public void setResultStatus(String resultStatus) { this.resultStatus = resultStatus; }
    public Boolean getMissingIn() { return missingIn; }
    public void setMissingIn(Boolean missingIn) { this.missingIn = missingIn; }
    public Boolean getMissingOut() { return missingOut; }
    public void setMissingOut(Boolean missingOut) { this.missingOut = missingOut; }
    public Integer getLateMinutes() { return lateMinutes; }
    public void setLateMinutes(Integer lateMinutes) { this.lateMinutes = lateMinutes; }
    public Integer getEarlyMinutes() { return earlyMinutes; }
    public void setEarlyMinutes(Integer earlyMinutes) { this.earlyMinutes = earlyMinutes; }
    public Integer getPlannedWorkMinutes() { return plannedWorkMinutes; }
    public void setPlannedWorkMinutes(Integer plannedWorkMinutes) { this.plannedWorkMinutes = plannedWorkMinutes; }
    public Integer getWorkMinutes() { return workMinutes; }
    public void setWorkMinutes(Integer workMinutes) { this.workMinutes = workMinutes; }
    public Integer getCalculationCount() { return calculationCount; }
    public void setCalculationCount(Integer calculationCount) { this.calculationCount = calculationCount; }
    public String getCalculatedBy() { return calculatedBy; }
    public void setCalculatedBy(String calculatedBy) { this.calculatedBy = calculatedBy; }
    public Date getCalculatedTime() { return calculatedTime; }
    public void setCalculatedTime(Date calculatedTime) { this.calculatedTime = calculatedTime; }
    public AttDailyRuleSnapshot getRuleConfig() { return ruleConfig; }
    public void setRuleConfig(AttDailyRuleSnapshot ruleConfig) { this.ruleConfig = ruleConfig; }
}
