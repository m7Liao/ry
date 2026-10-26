package com.ruoyi.attendance.domain.vo;

import com.ruoyi.attendance.domain.AttEmployee;

/** 移动端本人身份投影，不返回系统账号完整实体。 */
public class AttCheckinIdentityView
{
    private final String employeeName;
    private final String employeeNo;
    private final String userName;
    private final String deptName;
    private final String siteName;
    private final String status;

    public AttCheckinIdentityView(AttEmployee employee)
    {
        employeeName = employee.getEmployeeName();
        employeeNo = employee.getEmployeeNo();
        userName = employee.getUserName();
        deptName = employee.getDeptName();
        siteName = employee.getSiteName();
        status = employee.getStatus();
    }

    public String getEmployeeName() { return employeeName; }
    public String getEmployeeNo() { return employeeNo; }
    public String getUserName() { return userName; }
    public String getDeptName() { return deptName; }
    public String getSiteName() { return siteName; }
    public String getStatus() { return status; }
}
