package com.ruoyi.attendance.domain;
import java.math.BigDecimal;
import java.time.LocalDate;
import jakarta.validation.constraints.*;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.core.domain.BaseEntity;

/** 办公场所。 */
public class AttSite extends BaseEntity
{
    private static final long serialVersionUID = 1L;
    private Long siteId;
    @NotBlank(message = "场所编码不能为空") @Size(max = 32) @Pattern(regexp = "[A-Za-z0-9_-]+", message = "场所编码只能包含字母、数字、下划线和短横线")
    private String siteCode;
    @NotBlank(message = "场所名称不能为空") @Size(max = 100)
    private String siteName;
    @NotNull(message = "管理部门不能为空") @Positive
    private Long deptId;
    @NotBlank(message = "详细地址不能为空") @Size(max = 255)
    private String address;
    @DecimalMin("-180") @DecimalMax("180") @Digits(integer = 3, fraction = 6)
    private BigDecimal longitude;
    @DecimalMin("-90") @DecimalMax("90") @Digits(integer = 2, fraction = 6)
    private BigDecimal latitude;
    @NotBlank @Pattern(regexp = "GCJ02|WGS84|BD09", message = "坐标系不正确")
    private String coordinateSystem;
    @Size(max = 50)
    private String contactName;
    @Size(max = 30) @Pattern(regexp = "[0-9+() -]*", message = "联系电话格式不正确")
    private String contactPhone;
    @NotBlank @Pattern(regexp = "[01]", message = "场所状态不正确")
    private String status;
    private String deptName;
    private Integer employeeCount;
    public Long getSiteId() { return siteId; }
    public void setSiteId(Long siteId) { this.siteId = siteId; }
    public String getSiteCode() { return siteCode; }
    public void setSiteCode(String siteCode) { this.siteCode = siteCode; }
    public String getSiteName() { return siteName; }
    public void setSiteName(String siteName) { this.siteName = siteName; }
    public Long getDeptId() { return deptId; }
    public void setDeptId(Long deptId) { this.deptId = deptId; }
    public String getAddress() { return address; }
    public void setAddress(String address) { this.address = address; }
    public BigDecimal getLongitude() { return longitude; }
    public void setLongitude(BigDecimal longitude) { this.longitude = longitude; }
    public BigDecimal getLatitude() { return latitude; }
    public void setLatitude(BigDecimal latitude) { this.latitude = latitude; }
    public String getCoordinateSystem() { return coordinateSystem; }
    public void setCoordinateSystem(String coordinateSystem) { this.coordinateSystem = coordinateSystem; }
    public String getContactName() { return contactName; }
    public void setContactName(String contactName) { this.contactName = contactName; }
    public String getContactPhone() { return contactPhone; }
    public void setContactPhone(String contactPhone) { this.contactPhone = contactPhone; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public String getDeptName() { return deptName; }
    public void setDeptName(String deptName) { this.deptName = deptName; }
    public Integer getEmployeeCount() { return employeeCount; }
    public void setEmployeeCount(Integer employeeCount) { this.employeeCount = employeeCount; }
    @Override @Size(max = 500, message = "备注不能超过500字")
    public String getRemark() { return super.getRemark(); }
}
