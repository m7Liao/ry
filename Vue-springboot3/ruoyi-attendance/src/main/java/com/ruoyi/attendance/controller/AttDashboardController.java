package com.ruoyi.attendance.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.attendance.domain.AttDashboardQuery;
import com.ruoyi.attendance.service.IAttDashboardService;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;

@RestController
@RequestMapping("/attendance/dashboard")
public class AttDashboardController extends BaseController
{
    private final IAttDashboardService service;
    public AttDashboardController(IAttDashboardService service) { this.service = service; }

    @PreAuthorize("@ss.hasPermi('attendance:dashboard:view')")
    @GetMapping
    public AjaxResult get(@Validated AttDashboardQuery query) { return success(service.getDashboard(query)); }
}
