package com.ruoyi.attendance.service.impl;

import java.time.LocalTime;
import java.util.Arrays;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.attendance.domain.AttRule;
import com.ruoyi.attendance.domain.AttSite;
import com.ruoyi.attendance.mapper.AttRuleMapper;
import com.ruoyi.attendance.mapper.AttSiteMapper;
import com.ruoyi.attendance.service.IAttRuleService;
import com.ruoyi.attendance.service.IAttSiteService;
import com.ruoyi.common.annotation.DataScope;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.spring.SpringUtils;

/** 简单固定班次配置；数据范围随场所当前管理部门变化。 */
@Service
public class AttRuleServiceImpl implements IAttRuleService
{
    private final AttRuleMapper mapper;
    private final AttSiteMapper siteMapper;
    private final IAttSiteService siteService;

    public AttRuleServiceImpl(AttRuleMapper mapper, AttSiteMapper siteMapper, IAttSiteService siteService)
    {
        this.mapper = mapper;
        this.siteMapper = siteMapper;
        this.siteService = siteService;
    }

    @Override
    @DataScope(deptAlias = "s")
    public List<AttRule> selectRuleList(AttRule query)
    {
        List<AttRule> rows = mapper.selectRuleList(query);
        rows.forEach(this::fillPreview);
        return rows;
    }

    @Override
    public AttRule getRule(Long ruleId)
    {
        AttRule query = new AttRule();
        query.setRuleId(ruleId);
        List<AttRule> rows = SpringUtils.getAopProxy(this).selectRuleList(query);
        if (rows.isEmpty()) throw new ServiceException("规则不存在或无权访问", 403);
        return rows.get(0);
    }

    @Override
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public int saveRule(AttRule rule, boolean edit)
    {
        // 先锁场所，再操作规则。与场所删除共用父行锁，避免检查与保存竞争。
        AttRule previous = null;
        if (edit)
        {
            if (rule.getRuleId() == null || rule.getRuleId() <= 0) throw new ServiceException("规则编号不正确");
            previous = getRule(rule.getRuleId());
            if (!Objects.equals(previous.getSiteId(), rule.getSiteId())) throw new ServiceException("已有规则不能更换办公场所");
        }
        AttSite site = siteMapper.lockSite(rule.getSiteId());
        if (site == null) throw new ServiceException("办公场所不存在或无权访问", 403);
        siteService.getSite(site.getSiteId());
        if (edit)
        {
            getRule(rule.getRuleId());
            if (rule.getVersion() == null) throw new ServiceException("请重新打开规则后保存");
        }
        else
        {
            if (!"0".equals(site.getStatus())) throw new ServiceException("不能为停用场所新增规则");
            if (mapper.countSiteRules(site.getSiteId()) > 0) throw new ServiceException("该场所已配置规则，请修改已有规则");
            rule.setRuleId(null);
        }
        validateRule(rule);
        if (edit)
        {
            rule.setUpdateBy(SecurityUtils.getUsername());
            int changed = mapper.updateRule(rule);
            if (changed == 0) throw new ServiceException("规则已被其他操作修改，请重新打开后保存");
            return changed;
        }
        rule.setCreateBy(SecurityUtils.getUsername());
        return mapper.insertRule(rule);
    }

    @Override
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public int deleteRule(Long ruleId)
    {
        AttRule rule = getRule(ruleId);
        if (siteMapper.lockSite(rule.getSiteId()) == null) throw new ServiceException("规则不存在或无权访问", 403);
        getRule(ruleId);
        return mapper.deleteRule(ruleId);
    }

    private void validateRule(AttRule rule)
    {
        rule.setRuleName(rule.getRuleName().trim());
        List<String> days = Arrays.asList(rule.getWorkDays().split(","));
        if (days.stream().distinct().count() != days.size()) throw new ServiceException("工作日不能重复选择");
        rule.setWorkDays(days.stream().sorted().collect(Collectors.joining(",")));
        int start = minute(rule.getStartTime());
        int end = minute(rule.getEndTime()) + ("1".equals(rule.getEndNextDay()) ? 1440 : 0);
        int span = end - start;
        if (span <= 0 || span > 1440) throw new ServiceException("班次时长必须大于0且不超过24小时，请检查下班日期");
        if (rule.getRestMinutes() >= span) throw new ServiceException("休息时长必须小于班次时长");
        if (start + rule.getStartAfterMinutes() >= end - rule.getEndBeforeMinutes()) throw new ServiceException("上班和下班打卡窗口不能重叠或相接");
        if (rule.getLateGraceMinutes() > rule.getStartAfterMinutes()) throw new ServiceException("迟到宽限不能超过上班后允许打卡的分钟数");
        if (rule.getEarlyGraceMinutes() > rule.getEndBeforeMinutes()) throw new ServiceException("早退宽限不能超过下班前允许打卡的分钟数");
    }

    private void fillPreview(AttRule rule)
    {
        int start = minute(rule.getStartTime());
        int end = minute(rule.getEndTime()) + ("1".equals(rule.getEndNextDay()) ? 1440 : 0);
        rule.setPlannedWorkMinutes(end - start - rule.getRestMinutes());
        rule.setStartWindow(clock(start - rule.getStartBeforeMinutes()) + " ～ " + clock(start + rule.getStartAfterMinutes()));
        rule.setEndWindow(clock(end - rule.getEndBeforeMinutes()) + " ～ " + clock(end + rule.getEndAfterMinutes()));
    }

    private int minute(String value) { return LocalTime.parse(value).toSecondOfDay() / 60; }

    private String clock(int minute)
    {
        int day = Math.floorDiv(minute, 1440);
        int time = Math.floorMod(minute, 1440);
        String prefix = day < 0 ? "前一日 " : day == 0 ? "当日 " : day == 1 ? "次日 " : "后两日 ";
        return prefix + String.format("%02d:%02d", time / 60, time % 60);
    }
}
