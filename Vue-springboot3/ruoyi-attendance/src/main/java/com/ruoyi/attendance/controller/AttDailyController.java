package com.ruoyi.attendance.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.attendance.domain.AttDailyQuery;
import com.ruoyi.attendance.domain.dto.*;
import com.ruoyi.attendance.service.IAttDailyService;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.enums.BusinessType;

@RestController
@RequestMapping("/attendance/daily")
public class AttDailyController extends BaseController
{
    private final IAttDailyService service;
    public AttDailyController(IAttDailyService service) { this.service = service; }

    @PreAuthorize("@ss.hasPermi('attendance:daily:list')")
    @GetMapping("/list")
    public TableDataInfo list(@Validated AttDailyQuery query)
    {
        startPage();
        try { return getDataTable(service.selectResultList(query)); }
        finally { clearPage(); }
    }

    @PreAuthorize("@ss.hasPermi('attendance:daily:query')")
    @GetMapping("/{id}")
    public AjaxResult get(@PathVariable Long id) { return success(service.getResult(id)); }

    @PreAuthorize("@ss.hasPermi('attendance:daily:calculate')")
    @Log(title = "每日考勤首次计算", businessType = BusinessType.INSERT)
    @PostMapping("/calculate")
    public AjaxResult calculate(@Validated @RequestBody AttDailyCalculateRequest request) { return success(service.calculate(request)); }

    @PreAuthorize("@ss.hasPermi('attendance:daily:recalculate')")
    @Log(title = "每日考勤按快照重算", businessType = BusinessType.UPDATE)
    @PostMapping("/recalculate")
    public AjaxResult recalculate(@Validated @RequestBody AttDailyRecalculateRequest request) { return success(service.recalculate(request.getResultIds())); }
}
