package com.ruoyi.attendance.domain;
import java.math.BigDecimal;
import java.time.LocalDate;
import jakarta.validation.constraints.*;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.core.domain.BaseEntity;

/** 员工业务档案，部门实时关联系统账号。 */
public class AttEmployee extends BaseEntity
{
    private static final long serialVersionUID = 1L;
    private Long employeeId;
    @NotBlank(message = "工号不能为空") @Size(max = 32) @Pattern(regexp = "[A-Za-z0-9_-]+", message = "工号只能包含字母、数字、下划线和短横线")
    private String employeeNo;
    @NotBlank(message = "员工姓名不能为空") @Size(max = 50)
    private String employeeName;
    @NotNull(message = "系统账号不能为空") @Positive
    private Long userId;
    @NotNull(message = "办公场所不能为空") @Positive
    private Long siteId;
    @Size(max = 30) @Pattern(regexp = "[0-9+() -]*", message = "联系电话格式不正确")
    private String phone;
    @Email(message = "邮箱格式不正确") @Size(max = 100)
    private String email;
    @NotNull(message = "入职日期不能为空") @PastOrPresent(message = "入职日期不能晚于今天") @JsonFormat(pattern = "yyyy-MM-dd")
    private LocalDate hireDate;
    @PastOrPresent(message = "离职日期不能晚于今天") @JsonFormat(pattern = "yyyy-MM-dd")
    private LocalDate leaveDate;
    @NotBlank @Pattern(regexp = "[01]", message = "员工状态不正确")
    private String status;
    private String userName;
    private String accountStatus;
    private Long deptId;
    private String deptName;
    private String siteName;
    private String siteStatus;
    public Long getEmployeeId() { return employeeId; }
    public void setEmployeeId(Long employeeId) { this.employeeId = employeeId; }
    public String getEmployeeNo() { return employeeNo; }
    public void setEmployeeNo(String employeeNo) { this.employeeNo = employeeNo; }
    public String getEmployeeName() { return employeeName; }
    public void setEmployeeName(String employeeName) { this.employeeName = employeeName; }
    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public Long getSiteId() { return siteId; }
    public void setSiteId(Long siteId) { this.siteId = siteId; }
    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public LocalDate getHireDate() { return hireDate; }
    public void setHireDate(LocalDate hireDate) { this.hireDate = hireDate; }
    public LocalDate getLeaveDate() { return leaveDate; }
    public void setLeaveDate(LocalDate leaveDate) { this.leaveDate = leaveDate; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public String getUserName() { return userName; }
    public void setUserName(String userName) { this.userName = userName; }
    public String getAccountStatus() { return accountStatus; }
    public void setAccountStatus(String accountStatus) { this.accountStatus = accountStatus; }
    public Long getDeptId() { return deptId; }
    public void setDeptId(Long deptId) { this.deptId = deptId; }
    public String getDeptName() { return deptName; }
    public void setDeptName(String deptName) { this.deptName = deptName; }
    public String getSiteName() { return siteName; }
    public void setSiteName(String siteName) { this.siteName = siteName; }
    public String getSiteStatus() { return siteStatus; }
    public void setSiteStatus(String siteStatus) { this.siteStatus = siteStatus; }
    @Override @Size(max = 500, message = "备注不能超过500字")
    public String getRemark() { return super.getRemark(); }
}
