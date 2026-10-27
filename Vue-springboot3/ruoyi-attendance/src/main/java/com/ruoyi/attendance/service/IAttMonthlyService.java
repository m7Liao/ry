package com.ruoyi.attendance.service;
import java.util.List;
import com.ruoyi.attendance.domain.AttMonthlyQuery;
import com.ruoyi.attendance.domain.vo.AttMonthlyRow;
public interface IAttMonthlyService {
    List<AttMonthlyRow> selectMonthly(AttMonthlyQuery query);
    List<AttMonthlyRow> selectMyMonthly(AttMonthlyQuery query);
}

