package com.ruoyi.attendance.domain.dto;

import java.io.Serializable;
import java.util.Date;
import jakarta.validation.constraints.*;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.core.domain.BaseEntity;

/** 扫码凭证请求，不接受员工身份或签到时间。 */
public class AttCheckinRequest implements Serializable
{
    private static final long serialVersionUID = 1L;

    /** 随机扫码凭证 */
    @NotBlank(message = "请扫描有效二维码")
    @Pattern(regexp = "[0-9a-f]{64}", message = "二维码凭证格式不正确")
    private String ticket;

    public String getTicket()
    {
        return ticket;
    }

    public void setTicket(String ticket)
    {
        this.ticket = ticket;
    }
}
