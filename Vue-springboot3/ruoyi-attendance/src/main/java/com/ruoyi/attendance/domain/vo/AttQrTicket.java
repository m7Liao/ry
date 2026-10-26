package com.ruoyi.attendance.domain.vo;

import java.io.Serializable;
import java.util.Date;
import jakarta.validation.constraints.*;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.core.domain.BaseEntity;

/** Redis 中的短期扫码凭证。 */
public class AttQrTicket implements Serializable
{
    private static final long serialVersionUID = 1L;

    /** 场次ID */
    private Long sessionId;

    /** 到期时间戳 */
    private Long expiresAt;

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
}
