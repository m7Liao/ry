package com.ruoyi.attendance.support;

import java.util.*;
import java.util.function.IntConsumer;
import java.util.function.Supplier;
import org.springframework.dao.*;
import com.ruoyi.common.exception.ServiceException;

public final class AttAutoSettleSupport
{
    private AttAutoSettleSupport() {}
    public static List<Long> siteIds(String value)
    {
        if (value == null || value.isBlank()) throw new ServiceException("请先配置需要自动日结的场所ID，不能留空或使用全部范围");
        String[] parts = value.split(",", -1);
        if (parts.length > 100) throw new ServiceException("每个任务最多配置100个场所");
        SortedSet<Long> ids = new TreeSet<>();
        try
        {
            for (String part : parts)
            {
                if (!part.trim().matches("[1-9][0-9]*")) throw new NumberFormatException();
                ids.add(Long.valueOf(part.trim()));
            }
        }
        catch (NumberFormatException e) { throw new ServiceException("场所范围必须为逗号分隔的正整数ID，例如1,2"); }
        return List.copyOf(ids);
    }

    public static <T> T retry(Supplier<T> action, IntConsumer retried)
    {
        for (int attempt = 1; ; attempt++)
        {
            try { return action.get(); }
            catch (TransientDataAccessException | DataAccessResourceFailureException e)
            {
                if (attempt >= 3) throw e;
                retried.accept(attempt);
            }
        }
    }
}
