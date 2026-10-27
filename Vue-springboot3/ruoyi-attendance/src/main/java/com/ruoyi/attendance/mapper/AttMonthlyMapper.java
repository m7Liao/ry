package com.ruoyi.attendance.mapper;
import java.util.List;
import com.ruoyi.attendance.domain.AttMonthlyQuery;
import com.ruoyi.attendance.domain.vo.AttMonthlyRow;
public interface AttMonthlyMapper { List<AttMonthlyRow> selectMonthly(AttMonthlyQuery query); }

