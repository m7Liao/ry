package com.ruoyi.attendance.domain;

/** 选择器专用投影，避免返回账号密码等系统用户字段。 */
public class AttOption
{
    private Long id;
    private String label;
    private String status;
    private Long deptId;
    private String deptName;
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getLabel() { return label; }
    public void setLabel(String label) { this.label = label; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public Long getDeptId() { return deptId; }
    public void setDeptId(Long deptId) { this.deptId = deptId; }
    public String getDeptName() { return deptName; }
    public void setDeptName(String deptName) { this.deptName = deptName; }
}
