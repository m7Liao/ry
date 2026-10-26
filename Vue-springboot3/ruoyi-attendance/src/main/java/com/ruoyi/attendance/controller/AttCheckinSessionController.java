package com.ruoyi.attendance.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.attendance.domain.AttCheckinSession;
import com.ruoyi.attendance.domain.dto.AttSessionCreateRequest;
import com.ruoyi.attendance.service.IAttCheckinSessionService;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.annotation.RateLimiter;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.common.enums.LimitType;

/** 签到场次与动态二维码管理。 */
@RestController
@RequestMapping("/attendance/session")
public class AttCheckinSessionController extends BaseController
{
    private final IAttCheckinSessionService service;
    public AttCheckinSessionController(IAttCheckinSessionService service) { this.service = service; }

    @PreAuthorize("@ss.hasPermi('attendance:session:list')")
    @GetMapping("/list")
    public TableDataInfo list(AttCheckinSession query)
    {
        startPage();
        return getDataTable(service.selectSessionList(query));
    }

    @PreAuthorize("@ss.hasAnyPermi('attendance:session:query,attendance:session:qrcode')")
    @GetMapping("/{id}")
    public AjaxResult get(@PathVariable Long id) { return success(service.getSession(id)); }

    @PreAuthorize("@ss.hasPermi('attendance:session:add')")
    @Log(title = "签到场次", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@Validated @RequestBody AttSessionCreateRequest request)
    {
        return success(service.createSession(request));
    }

    @PreAuthorize("@ss.hasPermi('attendance:session:edit')")
    @Log(title = "关闭签到场次", businessType = BusinessType.UPDATE)
    @PutMapping("/{id}/close")
    public AjaxResult close(@PathVariable Long id) { return toAjax(service.closeSession(id)); }

    @PreAuthorize("@ss.hasPermi('attendance:session:qrcode')")
    @RateLimiter(time = 60, count = 60, limitType = LimitType.IP)
    @PostMapping("/{id}/qrcode")
    public AjaxResult qrcode(@PathVariable Long id)
    {
        // 不记录返回凭证到操作日志；每个二维码可以由多名员工使用。
        return success(service.issueQrCode(id));
    }
}
