package com.ruoyi.attendance.service.impl;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.attendance.domain.AttDashboardQuery;
import com.ruoyi.attendance.domain.vo.*;
import com.ruoyi.attendance.mapper.AttDashboardMapper;
import com.ruoyi.attendance.service.IAttDashboardService;
import com.ruoyi.attendance.support.AttDailyCalculator;
import com.ruoyi.common.annotation.DataScope;
import com.ruoyi.common.exception.ServiceException;

/** 直接聚合有权限的每日快照，同一请求中的三个查询使用一致性视图。 */
@Service
public class AttDashboardServiceImpl implements IAttDashboardService
{
    private final AttDashboardMapper mapper;
    public AttDashboardServiceImpl(AttDashboardMapper mapper) { this.mapper = mapper; }

    @Override
    @DataScope(deptAlias = "r", userAlias = "r")
    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public AttDashboardView getDashboard(AttDashboardQuery query)
    {
        LocalDate today = LocalDate.now(AttDailyCalculator.ZONE);
        if (query.getBeginDate() == null && query.getEndDate() == null)
        {
            query.setBeginDate(today.minusDays(6)); query.setEndDate(today);
        }
        if (query.getBeginDate() == null || query.getEndDate() == null) throw new ServiceException("请同时提供开始日期和结束日期");
        long span = ChronoUnit.DAYS.between(query.getBeginDate(), query.getEndDate());
        if (span < 0) throw new ServiceException("开始日期不能晚于结束日期");
        if (span > 30) throw new ServiceException("每次最多统计31天，请缩小日期范围");
        if (query.getEndDate().isAfter(today)) throw new ServiceException("不能统计未来日期");
        if (query.getBeginDate().getYear() < 1000) throw new ServiceException("统计日期超出支持范围");

        AttDashboardMetrics summary = mapper.selectSummary(query);
        Map<LocalDate, AttDashboardMetrics> byDate = mapper.selectTrend(query).stream()
                .collect(Collectors.toMap(AttDashboardMetrics::getAttendanceDate, Function.identity()));
        List<AttDashboardMetrics> trend = new ArrayList<>();
        for (LocalDate date = query.getBeginDate(); !date.isAfter(query.getEndDate()); date = date.plusDays(1))
        {
            AttDashboardMetrics row = byDate.get(date);
            if (row == null) { row = new AttDashboardMetrics(); row.setAttendanceDate(date); }
            trend.add(row);
        }
        List<AttDashboardMetrics> allSites = mapper.selectSites(query);
        List<AttDashboardMetrics> sites = allSites.stream()
                .filter(s -> query.getSiteId() == null || query.getSiteId().equals(s.getSiteId())).toList();
        List<AttDashboardView.SiteOption> options = allSites.stream()
                .map(s -> new AttDashboardView.SiteOption(s.getSiteId(), s.getSiteName())).toList();
        return new AttDashboardView(query.getBeginDate(), query.getEndDate(), query.getSiteId(), summary, trend, sites, options);
    }
}
