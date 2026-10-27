package com.ruoyi.attendance.service.impl;

import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeParseException;
import java.util.List;
import org.springframework.stereotype.Service;
import com.ruoyi.attendance.domain.AttMonthlyQuery;
import com.ruoyi.attendance.domain.vo.AttMonthlyRow;
import com.ruoyi.attendance.mapper.AttMonthlyMapper;
import com.ruoyi.attendance.service.IAttMonthlyService;
import com.ruoyi.attendance.support.AttDailyCalculator;
import com.ruoyi.common.annotation.DataScope;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;

/** 仅聚合已经生成的每日快照，未生成日期不推断为缺勤。 */
@Service
public class AttMonthlyServiceImpl implements IAttMonthlyService {
    private final AttMonthlyMapper mapper;
    public AttMonthlyServiceImpl(AttMonthlyMapper mapper) { this.mapper = mapper; }
    @Override
    @DataScope(deptAlias = "r", userAlias = "r")
    public List<AttMonthlyRow> selectMonthly(AttMonthlyQuery query) {
        normalize(query);
        query.setUserId(null);
        return mapper.selectMonthly(query);
    }
    @Override
    public List<AttMonthlyRow> selectMyMonthly(AttMonthlyQuery query) {
        normalize(query);
        query.getParams().clear();
        query.setUserId(SecurityUtils.getUserId());
        query.setSiteId(null); query.setDeptId(null);
        query.setEmployeeNo(null); query.setEmployeeName(null);
        return mapper.selectMonthly(query);
    }
    private void normalize(AttMonthlyQuery query) {
        LocalDate today = LocalDate.now(AttDailyCalculator.ZONE);
        YearMonth month;
        try {
            month = query.getMonth() == null ? YearMonth.from(today) : YearMonth.parse(query.getMonth());
        } catch (DateTimeParseException e) { throw new ServiceException("月份格式应为yyyy-MM"); }
        if (month.getYear() < 1000 || month.isAfter(YearMonth.from(today))) throw new ServiceException("月份超出支持范围或属于未来");
        query.setMonth(month.toString());
        query.setBeginDate(month.atDay(1));
        query.setEndDate(month.atEndOfMonth().isAfter(today) ? today : month.atEndOfMonth());
    }
}

