package com.ruoyi.attendance.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.attendance.domain.AttCheckinRecord;
import com.ruoyi.attendance.service.IAttCheckinRecordService;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;

/** 原始签到记录管理查询，接口不提供改写和删除。 */
@RestController
@RequestMapping("/attendance/record")
public class AttCheckinRecordController extends BaseController
{
    private final IAttCheckinRecordService service;
    public AttCheckinRecordController(IAttCheckinRecordService service) { this.service = service; }

    @PreAuthorize("@ss.hasPermi('attendance:record:list')")
    @GetMapping("/list")
    public TableDataInfo list(@Validated AttCheckinRecord query)
    {
        startPage();
        try
        {
            return getDataTable(service.selectRecordList(query));
        }
        finally
        {
            // 日期等业务校验可能在执行 SQL 前失败，仍需清理线程分页状态。
            clearPage();
        }
    }

    @PreAuthorize("@ss.hasPermi('attendance:record:query')")
    @GetMapping("/{id}")
    public AjaxResult get(@PathVariable Long id) { return success(service.getRecord(id)); }
}
