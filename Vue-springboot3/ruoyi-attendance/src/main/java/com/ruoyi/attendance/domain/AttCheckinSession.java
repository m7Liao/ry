package com.ruoyi.attendance.domain;

import java.io.Serializable;
import java.util.Date;
import jakarta.validation.constraints.*;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.core.domain.BaseEntity;

/** 办公场所签到场次，关闭后保留历史。 */
public class AttCheckinSession extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 供页面展示的当前场次状态，以服务器时间判断。 */
    public String getSessionState()
    {
        if ("1".equals(status)) return "closed";
        if (endTime != null && !new Date().before(endTime)) return "expired";
        return "open";
    }

    /** 场次ID */
    private Long sessionId;

    /** 办公场所ID */
    private Long siteId;

    /** 创建时的管理部门ID */
    private Long deptId;

    /** 场次名称 */
    private String title;

    /** 开始时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "GMT+8")
    private Date startTime;

    /** 结束时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "GMT+8")
    private Date endTime;

    /** 0开放，1关闭 */
    private String status;

    /** 场所名称 */
    private String siteName;

    /** 场所编码 */
    private String siteCode;

    /** 签到人数 */
    private Integer recordCount;

    public Long getSessionId()
    {
        return sessionId;
    }

    public void setSessionId(Long sessionId)
    {
        this.sessionId = sessionId;
    }

    public Long getSiteId()
    {
        return siteId;
    }

    public void setSiteId(Long siteId)
    {
        this.siteId = siteId;
    }

    public Long getDeptId()
    {
        return deptId;
    }

    public void setDeptId(Long deptId)
    {
        this.deptId = deptId;
    }

    public String getTitle()
    {
        return title;
    }

    public void setTitle(String title)
    {
        this.title = title;
    }

    public Date getStartTime()
    {
        return startTime;
    }

    public void setStartTime(Date startTime)
    {
        this.startTime = startTime;
    }

    public Date getEndTime()
    {
        return endTime;
    }

    public void setEndTime(Date endTime)
    {
        this.endTime = endTime;
    }

    public String getStatus()
    {
        return status;
    }

    public void setStatus(String status)
    {
        this.status = status;
    }

    public String getSiteName()
    {
        return siteName;
    }

    public void setSiteName(String siteName)
    {
        this.siteName = siteName;
    }

    public String getSiteCode()
    {
        return siteCode;
    }

    public void setSiteCode(String siteCode)
    {
        this.siteCode = siteCode;
    }

    public Integer getRecordCount()
    {
        return recordCount;
    }

    public void setRecordCount(Integer recordCount)
    {
        this.recordCount = recordCount;
    }
}
