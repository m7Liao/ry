package com.ruoyi.attendance.mapper;

import java.util.List;
import com.ruoyi.attendance.domain.AttRule;

public interface AttRuleMapper
{
    List<AttRule> selectRuleList(AttRule query);
    int countSiteRules(Long siteId);
    int insertRule(AttRule rule);
    int updateRule(AttRule rule);
    int deleteRule(Long ruleId);
}
