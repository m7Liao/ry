package com.ruoyi.attendance.mapper;

import java.time.LocalDate;
import java.util.Date;
import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.attendance.domain.*;

public interface AttDailyMapper
{
    List<AttDailyResult> selectResultList(AttDailyQuery query);
    List<AttEmployee> selectCandidates(AttDailyQuery query);
    Long selectExistingId(@Param("employeeId") Long employeeId, @Param("attendanceDate") LocalDate attendanceDate);
    AttDailyResult lockResult(Long resultId);
    List<AttCheckinRecord> selectPunches(@Param("employeeId") Long employeeId, @Param("siteId") Long siteId,
            @Param("from") Date from, @Param("until") Date until, @Param("now") Date now, @Param("resultId") Long resultId);
    int insertResult(AttDailyResult result);
    int updateCalculation(AttDailyResult result);
    int countEmployeeResults(Long id);
    int countSiteResults(Long id);
    int countRuleResults(Long id);
}
