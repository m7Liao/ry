package com.ruoyi.attendance.domain.vo;

import java.time.LocalDate;
import java.util.List;

public record AttDashboardView(LocalDate beginDate, LocalDate endDate, Long siteId,
        AttDashboardMetrics summary, List<AttDashboardMetrics> trend, List<AttDashboardMetrics> sites,
        List<SiteOption> siteOptions)
{
    public record SiteOption(Long id, String label) {}
}
