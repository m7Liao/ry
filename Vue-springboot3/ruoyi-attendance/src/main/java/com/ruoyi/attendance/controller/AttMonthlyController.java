package com.ruoyi.attendance.controller;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.attendance.domain.AttMonthlyQuery;
import com.ruoyi.attendance.service.IAttMonthlyService;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.page.TableDataInfo;
@RestController
@RequestMapping("/attendance/monthly")
public class AttMonthlyController extends BaseController {
    private final IAttMonthlyService service;
    public AttMonthlyController(IAttMonthlyService service) { this.service = service; }
    @PreAuthorize("@ss.hasPermi('attendance:monthly:list')")
    @GetMapping("/list")
    public TableDataInfo list(@Validated AttMonthlyQuery query) {
        startPage();
        try { return getDataTable(service.selectMonthly(query)); } finally { clearPage(); }
    }
}

