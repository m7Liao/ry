package com.ruoyi.attendance.domain;

import java.time.LocalDate;
import jakarta.validation.constraints.*;
import com.ruoyi.common.core.domain.BaseEntity;

public class AttMonthlyQuery extends BaseEntity
{
    @Pattern(regexp = "[0-9]{4}-[0-9]{2}", message = "月份格式应为yyyy-MM")
    private String month;
    @Positive
    private Long siteId;
    @Positive
    private Long deptId;
    @Size(max=32)
    private String employeeNo;
    @Size(max=50)
    private String employeeName;
    private LocalDate beginDate;
    private LocalDate endDate;
    private Long userId;
    public String getMonth() { return month; }
    public void setMonth(String month) { this.month = month; }
    public Long getSiteId() { return siteId; }
    public void setSiteId(Long siteId) { this.siteId = siteId; }
    public Long getDeptId() { return deptId; }
    public void setDeptId(Long deptId) { this.deptId = deptId; }
    public String getEmployeeNo() { return employeeNo; }
    public void setEmployeeNo(String employeeNo) { this.employeeNo = employeeNo; }
    public String getEmployeeName() { return employeeName; }
    public void setEmployeeName(String employeeName) { this.employeeName = employeeName; }
    public LocalDate getBeginDate() { return beginDate; }
    public void setBeginDate(LocalDate beginDate) { this.beginDate = beginDate; }
    public LocalDate getEndDate() { return endDate; }
    public void setEndDate(LocalDate endDate) { this.endDate = endDate; }
    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
}

