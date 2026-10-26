package com.ruoyi.attendance.domain;

import java.io.Serializable;
import java.util.Date;
import jakarta.validation.constraints.*;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.core.domain.BaseEntity;

/** 原始签到记录，业务接口只允许追加和查询。 */
public class AttCheckinRecord extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 记录ID */
    private Long recordId;

    /** 签到场次ID */
    private Long sessionId;

    /** 员工档案ID */
    private Long employeeId;

    /** 签到账号ID */
    private Long userId;

    /** 签到时的员工部门ID */
    private Long deptId;

    /** 场所ID */
    private Long siteId;

    /** 签到时工号快照 */
    private String employeeNo;

    /** 签到时姓名快照 */
    private String employeeName;

    /** 签到时账号名快照 */
    private String userName;

    /** 签到时部门名快照 */
    private String deptName;

    /** 签到时场所名快照 */
    private String siteName;

    /** 签到场次名称 */
    private String sessionTitle;

    /** 服务器签到时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "GMT+8")
    private Date checkinTime;

    /** QR扫码 */
    private String checkinMethod;

    /** 筛选开始日期 */
    @Pattern(regexp = "^$|[0-9]{4}-[0-9]{2}-[0-9]{2}", message = "开始日期格式不正确")
    private String beginDate;

    /** 筛选结束日期 */
    @Pattern(regexp = "^$|[0-9]{4}-[0-9]{2}-[0-9]{2}", message = "结束日期格式不正确")
    private String endDate;

    public Long getRecordId()
    {
        return recordId;
    }

    public void setRecordId(Long recordId)
    {
        this.recordId = recordId;
    }

    public Long getSessionId()
    {
        return sessionId;
    }

    public void setSessionId(Long sessionId)
    {
        this.sessionId = sessionId;
    }

    public Long getEmployeeId()
    {
        return employeeId;
    }

    public void setEmployeeId(Long employeeId)
    {
        this.employeeId = employeeId;
    }

    public Long getUserId()
    {
        return userId;
    }

    public void setUserId(Long userId)
    {
        this.userId = userId;
    }

    public Long getDeptId()
    {
        return deptId;
    }

    public void setDeptId(Long deptId)
    {
        this.deptId = deptId;
    }

    public Long getSiteId()
    {
        return siteId;
    }

    public void setSiteId(Long siteId)
    {
        this.siteId = siteId;
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

    public String getUserName()
    {
        return userName;
    }

    public void setUserName(String userName)
    {
        this.userName = userName;
    }

    public String getDeptName()
    {
        return deptName;
    }

    public void setDeptName(String deptName)
    {
        this.deptName = deptName;
    }

    public String getSiteName()
    {
        return siteName;
    }

    public void setSiteName(String siteName)
    {
        this.siteName = siteName;
    }

    public String getSessionTitle()
    {
        return sessionTitle;
    }

    public void setSessionTitle(String sessionTitle)
    {
        this.sessionTitle = sessionTitle;
    }

    public Date getCheckinTime()
    {
        return checkinTime;
    }

    public void setCheckinTime(Date checkinTime)
    {
        this.checkinTime = checkinTime;
    }

    public String getCheckinMethod()
    {
        return checkinMethod;
    }

    public void setCheckinMethod(String checkinMethod)
    {
        this.checkinMethod = checkinMethod;
    }

    public String getBeginDate()
    {
        return beginDate;
    }

    public void setBeginDate(String beginDate)
    {
        this.beginDate = beginDate;
    }

    public String getEndDate()
    {
        return endDate;
    }

    public void setEndDate(String endDate)
    {
        this.endDate = endDate;
    }
}
