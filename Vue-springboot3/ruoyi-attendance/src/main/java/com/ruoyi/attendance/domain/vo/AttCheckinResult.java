package com.ruoyi.attendance.domain.vo;

import java.io.Serializable;
import java.util.Date;
import jakarta.validation.constraints.*;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.core.domain.BaseEntity;

/** 签到结果，重复提交返回同一条记录。 */
public class AttCheckinResult implements Serializable
{
    private static final long serialVersionUID = 1L;

    /** 记录ID */
    private Long recordId;

    /** 员工姓名 */
    private String employeeName;

    /** 场所名称 */
    private String siteName;

    /** 服务器签到时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "GMT+8")
    private Date checkinTime;

    /** 是否已在本场次签到 */
    private Boolean repeated;

    public Long getRecordId()
    {
        return recordId;
    }

    public void setRecordId(Long recordId)
    {
        this.recordId = recordId;
    }

    public String getEmployeeName()
    {
        return employeeName;
    }

    public void setEmployeeName(String employeeName)
    {
        this.employeeName = employeeName;
    }

    public String getSiteName()
    {
        return siteName;
    }

    public void setSiteName(String siteName)
    {
        this.siteName = siteName;
    }

    public Date getCheckinTime()
    {
        return checkinTime;
    }

    public void setCheckinTime(Date checkinTime)
    {
        this.checkinTime = checkinTime;
    }

    public Boolean getRepeated()
    {
        return repeated;
    }

    public void setRepeated(Boolean repeated)
    {
        this.repeated = repeated;
    }
}
