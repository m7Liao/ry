package com.ruoyi.attendance.mapper;

import java.util.List;
import com.ruoyi.attendance.domain.AttDashboardQuery;
import com.ruoyi.attendance.domain.vo.AttDashboardMetrics;

public interface AttDashboardMapper
{
    AttDashboardMetrics selectSummary(AttDashboardQuery query);
    List<AttDashboardMetrics> selectTrend(AttDashboardQuery query);
    List<AttDashboardMetrics> selectSites(AttDashboardQuery query);
}
