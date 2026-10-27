package com.ruoyi.attendance.domain;
import java.util.Date;
import com.fasterxml.jackson.annotation.JsonIgnore;
public class AttFaceProfile {
    private Long employeeId;
    @JsonIgnore private byte[] encryptedFeature;
    private String model, updatedBy;
    private long version;
    private Date updatedTime;
    public Long getEmployeeId() { return employeeId; }
    public void setEmployeeId(Long v) { employeeId=v; }
    public byte[] getEncryptedFeature() { return encryptedFeature; }
    public void setEncryptedFeature(byte[] v) { encryptedFeature=v; }
    public String getModel() { return model; }
    public void setModel(String v) { model=v; }
    public String getUpdatedBy() { return updatedBy; }
    public void setUpdatedBy(String v) { updatedBy=v; }
    public long getVersion() { return version; }
    public void setVersion(long v) { version=v; }
    public Date getUpdatedTime() { return updatedTime; }
    public void setUpdatedTime(Date v) { updatedTime=v; }
}
