package com.ruoyi.attendance.domain.dto;

import java.io.Serializable;
import java.util.Date;
import jakarta.validation.constraints.*;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.core.domain.BaseEntity;

/** 创建场次请求，开始时间和部门由后端确定。 */
public class AttSessionCreateRequest implements Serializable
{
    private static final long serialVersionUID = 1L;

    /** 办公场所ID */
    @NotNull(message = "请选择办公场所")
    @Positive
    private Long siteId;

    /** 场次名称 */
    @NotBlank(message = "场次名称不能为空")
    @Size(max = 100)
    private String title;

    /** 有效时长，5分钟至24小时 */
    @NotNull(message = "请选择场次时长")
    @Min(5)
    @Max(1440)
    private Integer durationMinutes;

    public Long getSiteId()
    {
        return siteId;
    }

    public void setSiteId(Long siteId)
    {
        this.siteId = siteId;
    }

    public String getTitle()
    {
        return title;
    }

    public void setTitle(String title)
    {
        this.title = title;
    }

    public Integer getDurationMinutes()
    {
        return durationMinutes;
    }

    public void setDurationMinutes(Integer durationMinutes)
    {
        this.durationMinutes = durationMinutes;
    }
}
