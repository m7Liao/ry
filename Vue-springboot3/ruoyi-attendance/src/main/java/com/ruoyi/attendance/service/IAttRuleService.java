package com.ruoyi.attendance.service;

import java.util.List;
import com.ruoyi.attendance.domain.AttRule;

public interface IAttRuleService
{
    List<AttRule> selectRuleList(AttRule query);
    AttRule getRule(Long ruleId);
    int saveRule(AttRule rule, boolean edit);
    int deleteRule(Long ruleId);
}
