package com.ruoyi.attendance.service;

import java.util.List;
import java.util.Map;
import com.ruoyi.attendance.domain.*;
import com.ruoyi.attendance.domain.dto.AttDailyCalculateRequest;

public interface IAttDailyService
{
    List<AttDailyResult> selectResultList(AttDailyQuery query);
    List<AttEmployee> selectCandidates(AttDailyQuery query);
    AttDailyResult getResult(Long resultId);
    Map<String, Integer> calculate(AttDailyCalculateRequest request);
    int recalculate(List<Long> resultIds);
}
