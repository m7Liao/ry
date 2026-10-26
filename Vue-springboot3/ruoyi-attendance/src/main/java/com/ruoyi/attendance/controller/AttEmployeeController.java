package com.ruoyi.attendance.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.attendance.domain.AttEmployee;
import com.ruoyi.attendance.service.*;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.enums.BusinessType;

@RestController
@RequestMapping("/attendance/employee")
public class AttEmployeeController extends BaseController
{
    private final AttService service;
    private final AttScopeService scope;
    public AttEmployeeController(AttService service, AttScopeService scope) { this.service = service; this.scope = scope; }

    @PreAuthorize("@ss.hasPermi('attendance:employee:list')")
    @GetMapping("/list")
    public TableDataInfo list(AttEmployee query) { startPage(); return getDataTable(scope.employees(query)); }

    @PreAuthorize("@ss.hasAnyPermi('attendance:employee:query,attendance:employee:edit')")
    @GetMapping("/{id}")
    public AjaxResult get(@PathVariable Long id) { return success(service.employee(id)); }

    @PreAuthorize("@ss.hasPermi('attendance:employee:add')")
    @GetMapping("/users")
    public AjaxResult users(String keyword) {
        SysUser query = new SysUser(); query.setUserName(keyword);
        return success(scope.users(query));
    }

    @PreAuthorize("@ss.hasPermi('attendance:employee:add')")
    @Log(title = "员工档案", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@Validated @RequestBody AttEmployee employee) { return toAjax(service.saveEmployee(employee, false)); }

    @PreAuthorize("@ss.hasPermi('attendance:employee:edit')")
    @Log(title = "员工档案", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@Validated @RequestBody AttEmployee employee) { return toAjax(service.saveEmployee(employee, true)); }

    @PreAuthorize("@ss.hasPermi('attendance:employee:remove')")
    @Log(title = "员工档案", businessType = BusinessType.DELETE)
    @DeleteMapping("/{ids}")
    public AjaxResult delete(@PathVariable Long[] ids) { return toAjax(service.deleteEmployees(ids)); }
}
