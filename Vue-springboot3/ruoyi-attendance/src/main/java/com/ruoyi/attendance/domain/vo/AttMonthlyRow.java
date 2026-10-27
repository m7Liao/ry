package com.ruoyi.attendance.domain.vo;


public class AttMonthlyRow
{
    private Long employeeId;
    private String employeeNo;
    private String employeeName;
    private String deptName;
    private long generatedDays;
    private long workDays;
    private long settledDays;
    private long attendedDays;
    private long normalDays;
    private long abnormalDays;
    private long pendingDays;
    private long restDays;
    private long missingDays;
    private long lateDays;
    private long earlyDays;
    private long lateMinutes;
    private long earlyMinutes;
    private long plannedWorkMinutes;
    private long settledPlannedMinutes;
    private long workMinutes;
    private long unknownWorkDays;
    public Long getEmployeeId() { return employeeId; }
    public void setEmployeeId(Long employeeId) { this.employeeId = employeeId; }
    public String getEmployeeNo() { return employeeNo; }
    public void setEmployeeNo(String employeeNo) { this.employeeNo = employeeNo; }
    public String getEmployeeName() { return employeeName; }
    public void setEmployeeName(String employeeName) { this.employeeName = employeeName; }
    public String getDeptName() { return deptName; }
    public void setDeptName(String deptName) { this.deptName = deptName; }
    public long getGeneratedDays() { return generatedDays; }
    public void setGeneratedDays(long generatedDays) { this.generatedDays = generatedDays; }
    public long getWorkDays() { return workDays; }
    public void setWorkDays(long workDays) { this.workDays = workDays; }
    public long getSettledDays() { return settledDays; }
    public void setSettledDays(long settledDays) { this.settledDays = settledDays; }
    public long getAttendedDays() { return attendedDays; }
    public void setAttendedDays(long attendedDays) { this.attendedDays = attendedDays; }
    public long getNormalDays() { return normalDays; }
    public void setNormalDays(long normalDays) { this.normalDays = normalDays; }
    public long getAbnormalDays() { return abnormalDays; }
    public void setAbnormalDays(long abnormalDays) { this.abnormalDays = abnormalDays; }
    public long getPendingDays() { return pendingDays; }
    public void setPendingDays(long pendingDays) { this.pendingDays = pendingDays; }
    public long getRestDays() { return restDays; }
    public void setRestDays(long restDays) { this.restDays = restDays; }
    public long getMissingDays() { return missingDays; }
    public void setMissingDays(long missingDays) { this.missingDays = missingDays; }
    public long getLateDays() { return lateDays; }
    public void setLateDays(long lateDays) { this.lateDays = lateDays; }
    public long getEarlyDays() { return earlyDays; }
    public void setEarlyDays(long earlyDays) { this.earlyDays = earlyDays; }
    public long getLateMinutes() { return lateMinutes; }
    public void setLateMinutes(long lateMinutes) { this.lateMinutes = lateMinutes; }
    public long getEarlyMinutes() { return earlyMinutes; }
    public void setEarlyMinutes(long earlyMinutes) { this.earlyMinutes = earlyMinutes; }
    public long getPlannedWorkMinutes() { return plannedWorkMinutes; }
    public void setPlannedWorkMinutes(long plannedWorkMinutes) { this.plannedWorkMinutes = plannedWorkMinutes; }
    public long getSettledPlannedMinutes() { return settledPlannedMinutes; }
    public void setSettledPlannedMinutes(long settledPlannedMinutes) { this.settledPlannedMinutes = settledPlannedMinutes; }
    public long getWorkMinutes() { return workMinutes; }
    public void setWorkMinutes(long workMinutes) { this.workMinutes = workMinutes; }
    public long getUnknownWorkDays() { return unknownWorkDays; }
    public void setUnknownWorkDays(long unknownWorkDays) { this.unknownWorkDays = unknownWorkDays; }
}

