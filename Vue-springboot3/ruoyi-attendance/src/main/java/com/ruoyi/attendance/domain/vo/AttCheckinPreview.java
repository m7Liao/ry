package com.ruoyi.attendance.domain.vo;

import java.io.Serializable;
import java.util.Date;
import jakarta.validation.constraints.*;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.core.domain.BaseEntity;

/** 登录员工的签到确认信息。 */
public class AttCheckinPreview implements Serializable
{
    private static final long serialVersionUID = 1L;

    /** 场次ID */
    private Long sessionId;

    /** 场次名称 */
    private String title;

    /** 办公场所 */
    private String siteName;

    /** 本人工号 */
    private String employeeNo;

    /** 本人姓名 */
    private String employeeName;

    /** 二维码到期时间戳 */
    private Long expiresAt;

    /** 服务器时间戳 */
    private Long serverTime;

    /** 本人已签到记录ID，未签到为空 */
    private Long recordId;

    /** 已签到时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "GMT+8")
    private Date checkinTime;

    public Long getSessionId()
    {
        return sessionId;
    }

    public void setSessionId(Long sessionId)
    {
        this.sessionId = sessionId;
    }

    public String getTitle()
    {
        return title;
    }

    public void setTitle(String title)
    {
        this.title = title;
    }

    public String getSiteName()
    {
        return siteName;
    }

    public void setSiteName(String siteName)
    {
        this.siteName = siteName;
    }

    public String getEmployeeNo()
    {
        return employeeNo;
    }

    public void setEmployeeNo(String employeeNo)
    {
        this.employeeNo = employeeNo;
    }

    public String getEmployeeName()
    {
        return employeeName;
    }

    public void setEmployeeName(String employeeName)
    {
        this.employeeName = employeeName;
    }

    public Long getExpiresAt()
    {
        return expiresAt;
    }

    public void setExpiresAt(Long expiresAt)
    {
        this.expiresAt = expiresAt;
    }

    public Long getServerTime()
    {
        return serverTime;
    }

    public void setServerTime(Long serverTime)
    {
        this.serverTime = serverTime;
    }

    public Long getRecordId()
    {
        return recordId;
    }

    public void setRecordId(Long recordId)
    {
        this.recordId = recordId;
    }

    public Date getCheckinTime()
    {
        return checkinTime;
    }

    public void setCheckinTime(Date checkinTime)
    {
        this.checkinTime = checkinTime;
    }
}
