package com.ruoyi.attendance.mapper;

import java.time.LocalDate;
import java.util.Date;
import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.attendance.domain.*;

/** 自动入口无登录上下文，只能由任务对明确场所调用。 */
public interface AttAutoSettleMapper
{
    AttSite selectSite(Long siteId);
    AttRule selectRule(Long siteId);
    List<Long> selectMissingEmployees(@Param("siteId") Long siteId, @Param("date") LocalDate date);
    AttEmployee selectEmployee(@Param("siteId") Long siteId, @Param("employeeId") Long employeeId, @Param("date") LocalDate date);
    List<Long> selectClosedPending(@Param("siteId") Long siteId, @Param("now") Date now);
}
