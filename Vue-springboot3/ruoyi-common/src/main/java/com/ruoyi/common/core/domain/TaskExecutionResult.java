package com.ruoyi.common.core.domain;

/** 任务可选的执行摘要，供调度日志记录；普通 void 任务保持原行为。 */
public record TaskExecutionResult(boolean success, String message) {}
