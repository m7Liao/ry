package com.ruoyi.attendance.domain.vo;

import java.io.Serializable;
import java.util.Date;
import jakarta.validation.constraints.*;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.core.domain.BaseEntity;

/** 管理员二维码数据。 */
public class AttQrCodeView implements Serializable
{
    private static final long serialVersionUID = 1L;

    /** 随机凭证 */
    private String ticket;

    /** 场次ID */
    private Long sessionId;

    /** 二维码到期时间戳 */
    private Long expiresAt;

    /** 服务器时间戳 */
    private Long serverTime;

    /** 场次名称 */
    private String title;

    /** 场所名称 */
    private String siteName;

    public String getTicket()
    {
        return ticket;
    }

    public void setTicket(String ticket)
    {
        this.ticket = ticket;
    }

    public Long getSessionId()
    {
        return sessionId;
    }

    public void setSessionId(Long sessionId)
    {
        this.sessionId = sessionId;
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
}
