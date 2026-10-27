package com.ruoyi.attendance.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.attendance.domain.AttCheckinRecord;
import com.ruoyi.attendance.domain.AttDailyQuery;
import com.ruoyi.attendance.domain.AttMonthlyQuery;
import com.ruoyi.attendance.service.IAttMonthlyService;
import com.ruoyi.attendance.domain.AttDailyResult;
import com.ruoyi.attendance.domain.vo.AttMyDailyResult;
import com.ruoyi.attendance.domain.dto.AttCheckinRequest;
import com.ruoyi.attendance.service.IAttCheckinService;
import com.ruoyi.attendance.service.IAttCheckinRecordService;
import com.ruoyi.attendance.service.IAttDailyService;
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
    private final IAttDailyService dailyService;
    private final IAttMonthlyService monthlyService;
    public AttCheckinController(IAttCheckinService service, IAttCheckinRecordService recordService, IAttDailyService dailyService, IAttMonthlyService monthlyService)
    {
        this.service = service;
        this.recordService = recordService;
        this.dailyService = dailyService;
        this.monthlyService = monthlyService;
    }

    @PreAuthorize("@ss.hasPermi('attendance:checkin:submit')")
    @GetMapping("/me")
    public AjaxResult me() { return success(service.getIdentity()); }

    @PreAuthorize("@ss.hasPermi('attendance:checkin:submit')")
    @RateLimiter(time = 60, count = 60, limitType = LimitType.IP)
    @GetMapping("/face-status")
    public AjaxResult faceStatus() { return success(service.faceStatus()); }

    @PreAuthorize("@ss.hasPermi('attendance:checkin:submit')")
    @RateLimiter(time = 60, count = 60, limitType = LimitType.IP)
    @PostMapping(value="/face-submit", consumes="multipart/form-data")
    public AjaxResult faceSubmit(@RequestParam String ticket, @RequestParam org.springframework.web.multipart.MultipartFile image)
    {
        if (!ticket.matches("[0-9a-f]{64}")) throw new com.ruoyi.common.exception.ServiceException("二维码凭证格式不正确");
        return success(service.submitWithFace(ticket, image));
    }

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
    @GetMapping("/monthly")
    public AjaxResult monthly(@Validated AttMonthlyQuery query)
    {
        service.getIdentity();
        return success(monthlyService.selectMyMonthly(query));
    }

    @PreAuthorize("@ss.hasPermi('attendance:checkin:submit')")
    @GetMapping("/daily")
    public TableDataInfo daily(@Validated AttDailyQuery query)
    {
        service.getIdentity();
        startPage();
        try
        {
            java.util.List<AttDailyResult> rows = dailyService.selectMyResultList(query);
            TableDataInfo page = getDataTable(rows);
            page.setRows(rows.stream().map(AttMyDailyResult::from).toList());
            return page;
        }
        finally { clearPage(); }
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
