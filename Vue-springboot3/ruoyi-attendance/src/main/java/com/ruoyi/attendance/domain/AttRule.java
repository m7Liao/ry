package com.ruoyi.attendance.domain;

import jakarta.validation.constraints.*;
import com.ruoyi.common.core.domain.BaseEntity;

/** 一个办公场所对应一套固定班次参数，不直接改写原始签到记录。 */
public class AttRule extends BaseEntity
{
    private static final long serialVersionUID = 1L;
    private Long ruleId;
    @NotNull(message = "办公场所不能为空") @Positive
    private Long siteId;
    @NotBlank(message = "规则名称不能为空") @Size(max = 100)
    private String ruleName;
    @NotBlank(message = "请选择工作日")
    @Pattern(regexp = "[1-7](,[1-7]){0,6}", message = "工作日必须为1至7的逗号分隔值")
    private String workDays;
    @NotBlank @Pattern(regexp = "([01][0-9]|2[0-3]):[0-5][0-9]", message = "上班时间格式应为HH:mm")
    private String startTime;
    @NotBlank @Pattern(regexp = "([01][0-9]|2[0-3]):[0-5][0-9]", message = "下班时间格式应为HH:mm")
    private String endTime;
    @NotBlank @Pattern(regexp = "[01]", message = "下班日期不正确")
    private String endNextDay;
    @NotNull @Min(0) @Max(180)
    private Integer lateGraceMinutes;
    @NotNull @Min(0) @Max(180)
    private Integer earlyGraceMinutes;
    @NotNull @Min(0) @Max(360)
    private Integer startBeforeMinutes;
    @NotNull @Min(0) @Max(360)
    private Integer startAfterMinutes;
    @NotNull @Min(0) @Max(360)
    private Integer endBeforeMinutes;
    @NotNull @Min(0) @Max(360)
    private Integer endAfterMinutes;
    @NotNull @Min(0) @Max(720)
    private Integer restMinutes;
    @NotBlank @Pattern(regexp = "[01]", message = "规则状态不正确")
    private String status;
    @Min(0)
    private Integer version;
    private String siteName;
    private String siteCode;
    private String siteStatus;
    private String deptName;
    private Integer plannedWorkMinutes;
    private String startWindow;
    private String endWindow;

    public Long getRuleId() { return ruleId; }
    public void setRuleId(Long ruleId) { this.ruleId = ruleId; }
    public Long getSiteId() { return siteId; }
    public void setSiteId(Long siteId) { this.siteId = siteId; }
    public String getRuleName() { return ruleName; }
    public void setRuleName(String ruleName) { this.ruleName = ruleName; }
    public String getWorkDays() { return workDays; }
    public void setWorkDays(String workDays) { this.workDays = workDays; }
    public String getStartTime() { return startTime; }
    public void setStartTime(String startTime) { this.startTime = startTime; }
    public String getEndTime() { return endTime; }
    public void setEndTime(String endTime) { this.endTime = endTime; }
    public String getEndNextDay() { return endNextDay; }
    public void setEndNextDay(String endNextDay) { this.endNextDay = endNextDay; }
    public Integer getLateGraceMinutes() { return lateGraceMinutes; }
    public void setLateGraceMinutes(Integer lateGraceMinutes) { this.lateGraceMinutes = lateGraceMinutes; }
    public Integer getEarlyGraceMinutes() { return earlyGraceMinutes; }
    public void setEarlyGraceMinutes(Integer earlyGraceMinutes) { this.earlyGraceMinutes = earlyGraceMinutes; }
    public Integer getStartBeforeMinutes() { return startBeforeMinutes; }
    public void setStartBeforeMinutes(Integer startBeforeMinutes) { this.startBeforeMinutes = startBeforeMinutes; }
    public Integer getStartAfterMinutes() { return startAfterMinutes; }
    public void setStartAfterMinutes(Integer startAfterMinutes) { this.startAfterMinutes = startAfterMinutes; }
    public Integer getEndBeforeMinutes() { return endBeforeMinutes; }
    public void setEndBeforeMinutes(Integer endBeforeMinutes) { this.endBeforeMinutes = endBeforeMinutes; }
    public Integer getEndAfterMinutes() { return endAfterMinutes; }
    public void setEndAfterMinutes(Integer endAfterMinutes) { this.endAfterMinutes = endAfterMinutes; }
    public Integer getRestMinutes() { return restMinutes; }
    public void setRestMinutes(Integer restMinutes) { this.restMinutes = restMinutes; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public Integer getVersion() { return version; }
    public void setVersion(Integer version) { this.version = version; }
    public String getSiteName() { return siteName; }
    public void setSiteName(String siteName) { this.siteName = siteName; }
    public String getSiteCode() { return siteCode; }
    public void setSiteCode(String siteCode) { this.siteCode = siteCode; }
    public String getSiteStatus() { return siteStatus; }
    public void setSiteStatus(String siteStatus) { this.siteStatus = siteStatus; }
    public String getDeptName() { return deptName; }
    public void setDeptName(String deptName) { this.deptName = deptName; }
    public Integer getPlannedWorkMinutes() { return plannedWorkMinutes; }
    public void setPlannedWorkMinutes(Integer plannedWorkMinutes) { this.plannedWorkMinutes = plannedWorkMinutes; }
    public String getStartWindow() { return startWindow; }
    public void setStartWindow(String startWindow) { this.startWindow = startWindow; }
    public String getEndWindow() { return endWindow; }
    public void setEndWindow(String endWindow) { this.endWindow = endWindow; }
    @Override @Size(max = 500, message = "备注不能超过500字")
    public String getRemark() { return super.getRemark(); }
}
