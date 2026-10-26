package com.ruoyi.attendance.controller;

import org.springframework.core.annotation.Order;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.dao.ConcurrencyFailureException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import com.ruoyi.common.core.domain.AjaxResult;

/** 数据库约束兜底并发写入，响应不暴露 SQL 和个人数据。 */
@Order(0)
@RestControllerAdvice(basePackages = "com.ruoyi.attendance.controller")
public class AttExceptionHandler
{
    @ExceptionHandler(org.springframework.data.redis.RedisConnectionFailureException.class)
    public AjaxResult cacheUnavailable(org.springframework.data.redis.RedisConnectionFailureException e)
    {
        return AjaxResult.error("签到缓存暂时不可用，请稍后重试");
    }
    @ExceptionHandler(DuplicateKeyException.class)
    public AjaxResult duplicate(DuplicateKeyException e) { return AjaxResult.error("编码、工号或账号绑定已存在，请刷新后重试"); }
    @ExceptionHandler(DataIntegrityViolationException.class)
    public AjaxResult referenced(DataIntegrityViolationException e) { return AjaxResult.error("关联数据已变化或仍被引用，请刷新后重试"); }
    @ExceptionHandler(ConcurrencyFailureException.class)
    public AjaxResult concurrent(ConcurrencyFailureException e) { return AjaxResult.error("数据正在被其他操作修改，请稍后重试"); }
}
