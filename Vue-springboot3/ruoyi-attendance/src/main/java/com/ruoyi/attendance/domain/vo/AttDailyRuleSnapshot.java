package com.ruoyi.attendance.domain.vo;

import com.ruoyi.attendance.domain.AttRule;

/** 只保存计算所需参数，避免把权限 SQL 或可变资料放进快照。 */
public record AttDailyRuleSnapshot(String algorithm, Long ruleId, String ruleName, Integer version,
        String workDays, String startTime, String endTime, String endNextDay,
        int lateGraceMinutes, int earlyGraceMinutes, int startBeforeMinutes, int startAfterMinutes,
        int endBeforeMinutes, int endAfterMinutes, int restMinutes)
{
    public static AttDailyRuleSnapshot from(AttRule rule)
    {
        return new AttDailyRuleSnapshot("FIXED_V1", rule.getRuleId(), rule.getRuleName(), rule.getVersion(),
                rule.getWorkDays(), rule.getStartTime(), rule.getEndTime(), rule.getEndNextDay(),
                rule.getLateGraceMinutes(), rule.getEarlyGraceMinutes(), rule.getStartBeforeMinutes(),
                rule.getStartAfterMinutes(), rule.getEndBeforeMinutes(), rule.getEndAfterMinutes(), rule.getRestMinutes());
    }
}
