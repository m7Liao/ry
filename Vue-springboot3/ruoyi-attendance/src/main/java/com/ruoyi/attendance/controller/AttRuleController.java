package com.ruoyi.attendance.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.attendance.domain.AttRule;
import com.ruoyi.attendance.service.IAttRuleService;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.enums.BusinessType;

/** 固定班次配置，当前阶段不执行每日考勤结算。 */
@RestController
@RequestMapping("/attendance/rule")
public class AttRuleController extends BaseController
{
    private final IAttRuleService service;
    public AttRuleController(IAttRuleService service) { this.service = service; }

    @PreAuthorize("@ss.hasPermi('attendance:rule:list')")
    @GetMapping("/list")
    public TableDataInfo list(AttRule query)
    {
        startPage();
        try { return getDataTable(service.selectRuleList(query)); }
        finally { clearPage(); }
    }

    @PreAuthorize("@ss.hasAnyPermi('attendance:rule:query,attendance:rule:edit')")
    @GetMapping("/{id}")
    public AjaxResult get(@PathVariable Long id) { return success(service.getRule(id)); }

    @PreAuthorize("@ss.hasPermi('attendance:rule:add')")
    @Log(title = "考勤规则配置", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@Validated @RequestBody AttRule rule) { return toAjax(service.saveRule(rule, false)); }

    @PreAuthorize("@ss.hasPermi('attendance:rule:edit')")
    @Log(title = "考勤规则配置", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@Validated @RequestBody AttRule rule) { return toAjax(service.saveRule(rule, true)); }

    @PreAuthorize("@ss.hasPermi('attendance:rule:remove')")
    @Log(title = "考勤规则配置", businessType = BusinessType.DELETE)
    @DeleteMapping("/{id}")
    public AjaxResult delete(@PathVariable Long id) { return toAjax(service.deleteRule(id)); }
}
