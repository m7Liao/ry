package com.ruoyi.common.event;

/** 同步发布于删除事务内；业务模块可检查引用并抛出异常阻止删除。 */
public record BeforeSystemDelete(Target target, Long[] ids)
{
    public enum Target { USER, DEPARTMENT }
}
