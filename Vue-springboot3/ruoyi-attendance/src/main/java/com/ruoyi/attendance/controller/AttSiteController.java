package com.ruoyi.attendance.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import com.github.pagehelper.PageHelper;
import com.ruoyi.attendance.domain.AttSite;
import com.ruoyi.attendance.service.*;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.domain.entity.SysDept;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.enums.BusinessType;

@RestController
@RequestMapping("/attendance/site")
public class AttSiteController extends BaseController
{
    private final AttService service;
    private final AttScopeService scope;
    public AttSiteController(AttService service, AttScopeService scope) { this.service = service; this.scope = scope; }

    @PreAuthorize("@ss.hasPermi('attendance:site:list')")
    @GetMapping("/list")
    public TableDataInfo list(AttSite query) { startPage(); return getDataTable(scope.sites(query)); }

    @PreAuthorize("@ss.hasAnyPermi('attendance:site:query,attendance:site:edit')")
    @GetMapping("/{id}")
    public AjaxResult get(@PathVariable Long id) { return success(service.site(id)); }

    @PreAuthorize("@ss.hasAnyPermi('attendance:site:add,attendance:site:edit,attendance:site:list,attendance:employee:list')")
    @GetMapping("/departments")
    public AjaxResult departments() { return success(scope.departments(new SysDept())); }

    @PreAuthorize("@ss.hasAnyPermi('attendance:employee:add,attendance:employee:edit,attendance:employee:list')")
    @GetMapping("/options")
    public AjaxResult options(String keyword) {
        AttSite query = new AttSite(); query.setSiteName(keyword);
        PageHelper.startPage(1, 100, false);
        return success(scope.sites(query).stream().map(s -> {
            com.ruoyi.attendance.domain.AttOption option = new com.ruoyi.attendance.domain.AttOption();
            option.setId(s.getSiteId()); option.setLabel(s.getSiteName() + " / " + s.getSiteCode());
            option.setStatus(s.getStatus()); return option;
        }).toList());
    }

    @PreAuthorize("@ss.hasPermi('attendance:site:add')")
    @Log(title = "办公场所管理", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@Validated @RequestBody AttSite site) { return toAjax(service.saveSite(site, false)); }

    @PreAuthorize("@ss.hasPermi('attendance:site:edit')")
    @Log(title = "办公场所管理", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@Validated @RequestBody AttSite site) { return toAjax(service.saveSite(site, true)); }

    @PreAuthorize("@ss.hasPermi('attendance:site:remove')")
    @Log(title = "办公场所管理", businessType = BusinessType.DELETE)
    @DeleteMapping("/{ids}")
    public AjaxResult delete(@PathVariable Long[] ids) { return toAjax(service.deleteSites(ids)); }
}
