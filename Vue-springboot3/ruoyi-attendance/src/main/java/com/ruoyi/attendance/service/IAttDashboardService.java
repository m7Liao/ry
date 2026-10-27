package com.ruoyi.attendance.service;

import com.ruoyi.attendance.domain.AttDashboardQuery;
import com.ruoyi.attendance.domain.vo.AttDashboardView;

public interface IAttDashboardService
{
    AttDashboardView getDashboard(AttDashboardQuery query);
}
