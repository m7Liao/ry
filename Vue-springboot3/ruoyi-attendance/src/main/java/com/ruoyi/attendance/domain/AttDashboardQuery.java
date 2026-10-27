package com.ruoyi.attendance.domain;

import java.time.LocalDate;
import jakarta.validation.constraints.Positive;
import org.springframework.format.annotation.DateTimeFormat;
import com.ruoyi.common.core.domain.BaseEntity;

/** 看板仅接受日期与场所，数据权限由服务端生成。 */
public class AttDashboardQuery extends BaseEntity
{
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate beginDate;
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate endDate;
    @Positive(message = "场所编号不正确")
    private Long siteId;
    public LocalDate getBeginDate() { return beginDate; }
    public void setBeginDate(LocalDate beginDate) { this.beginDate = beginDate; }
    public LocalDate getEndDate() { return endDate; }
    public void setEndDate(LocalDate endDate) { this.endDate = endDate; }
    public Long getSiteId() { return siteId; }
    public void setSiteId(Long siteId) { this.siteId = siteId; }
}
