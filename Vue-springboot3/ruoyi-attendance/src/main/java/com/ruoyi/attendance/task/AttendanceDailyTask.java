package com.ruoyi.attendance.task;

import org.springframework.stereotype.Component;
import com.ruoyi.attendance.service.impl.AttAutoSettleService;
import com.ruoyi.common.core.domain.TaskExecutionResult;

/** 白名单内的任务适配器，不建立或模拟管理员 SecurityContext。 */
@Component("attendanceDailyTask")
public class AttendanceDailyTask
{
    private final AttAutoSettleService service;
    public AttendanceDailyTask(AttAutoSettleService service) { this.service = service; }
    public TaskExecutionResult settle(String siteIds) { return service.settle(siteIds); }
}
