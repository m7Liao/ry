package com.ruoyi.attendance.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.attendance.domain.AttCheckinRecord;
import com.ruoyi.attendance.domain.dto.AttCheckinRequest;
import com.ruoyi.attendance.service.IAttCheckinService;
import com.ruoyi.attendance.service.IAttCheckinRecordService;
import com.ruoyi.common.annotation.RateLimiter;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.enums.LimitType;

/** 移动端签到接口，员工身份只能由当前登录会话确定。 */
@RestController
@RequestMapping("/attendance/checkin")
public class AttCheckinController extends BaseController
{
    private final IAttCheckinService service;
    private final IAttCheckinRecordService recordService;
    public AttCheckinController(IAttCheckinService service, IAttCheckinRecordService recordService)
    {
        this.service = service;
        this.recordService = recordService;
    }

    @PreAuthorize("@ss.hasPermi('attendance:checkin:submit')")
    @GetMapping("/me")
    public AjaxResult me() { return success(service.getIdentity()); }

    @PreAuthorize("@ss.hasPermi('attendance:checkin:submit')")
    @RateLimiter(time = 60, count = 300, limitType = LimitType.IP)
    @PostMapping("/preview")
    public AjaxResult preview(@Validated @RequestBody AttCheckinRequest request)
    {
        return success(service.preview(request.getTicket()));
    }

    @PreAuthorize("@ss.hasPermi('attendance:checkin:submit')")
    @RateLimiter(time = 60, count = 300, limitType = LimitType.IP)
    @PostMapping("/submit")
    public AjaxResult submit(@Validated @RequestBody AttCheckinRequest request)
    {
        return success(service.submit(request.getTicket()));
    }

    @PreAuthorize("@ss.hasPermi('attendance:checkin:submit')")
    @GetMapping("/records")
    public TableDataInfo records(@Validated AttCheckinRecord query)
    {
        // 校验账号的查询必须在 startPage 之前，防止分页作用于身份校验 SQL。
        service.getIdentity();
        startPage();
        try
        {
            return getDataTable(recordService.selectMyRecordList(query));
        }
        finally
        {
            clearPage();
        }
    }
}
