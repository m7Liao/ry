package com.ruoyi.attendance.service.impl;

import java.util.Arrays;
import java.util.List;
import java.util.Objects;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.Isolation;
import com.ruoyi.attendance.domain.*;
import com.ruoyi.attendance.mapper.*;
import com.ruoyi.attendance.service.*;
import com.ruoyi.common.annotation.DataScope;
import com.ruoyi.common.core.domain.entity.SysDept;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.spring.SpringUtils;

/** 办公场所 服务层实现。 */
@Service
public class AttSiteServiceImpl implements IAttSiteService
{
    private final AttSiteMapper mapper;
    private final AttOptionMapper optionMapper;
    private final IAttOptionService optionService;
    private final AttCheckinSessionMapper sessionMapper;
    public AttSiteServiceImpl(AttSiteMapper mapper, AttOptionMapper optionMapper, IAttOptionService optionService,
            AttCheckinSessionMapper sessionMapper)
    {
        this.mapper = mapper;
        this.optionMapper = optionMapper;
        this.optionService = optionService;
        this.sessionMapper = sessionMapper;
    }

    @Override
    @DataScope(deptAlias = "s")
    public List<AttSite> selectSiteList(AttSite query)
    {
        return mapper.selectSites(query);
    }

    @Override
    public AttSite getSite(Long id)
    {
        AttSite query = new AttSite(); query.setSiteId(id);
        List<AttSite> rows = SpringUtils.getAopProxy(this).selectSiteList(query);
        if (rows.isEmpty()) throw new ServiceException("场所不存在或无权访问", 403);
        return rows.get(0);
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    @Override
    public int saveSite(AttSite site, boolean edit)
    {
        if (edit) {
            requireId(site.getSiteId());
            if (mapper.lockSite(site.getSiteId()) == null) throw new ServiceException("场所已被删除");
            getSite(site.getSiteId());
        } else site.setSiteId(null);
        SysDept dept = new SysDept(); dept.setDeptId(site.getDeptId());
        AttOption lockedDept = optionMapper.lockDepartment(site.getDeptId());
        if (lockedDept == null || !"0".equals(lockedDept.getStatus())) throw new ServiceException("管理部门已停用或删除");
        if (optionService.selectDepartmentOptions(dept).isEmpty()) throw new ServiceException("管理部门不存在、已停用或无权访问", 403);
        site.setSiteName(site.getSiteName().trim());
        site.setAddress(site.getAddress().trim());
        if ((site.getLongitude() == null) != (site.getLatitude() == null)) throw new ServiceException("经度和纬度必须同时填写或同时留空");
        if (mapper.countDuplicateSite(site.getSiteCode(), site.getSiteId()) > 0) throw new ServiceException("场所编码已存在");
        if (edit) { site.setUpdateBy(SecurityUtils.getUsername()); return mapper.updateSite(site); }
        site.setCreateBy(SecurityUtils.getUsername()); return mapper.insertSite(site);
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    @Override
    public int deleteSites(Long[] ids)
    {
        validateIds(ids);
        int count = 0;
        for (Long id : Arrays.stream(ids).distinct().sorted().toList()) {
            if (mapper.lockSite(id) == null) throw new ServiceException("场所已被删除");
            getSite(id);
            if (mapper.countSiteEmployees(id) > 0) throw new ServiceException("场所仍绑定员工，请先修改或删除员工档案");
            if (sessionMapper.countSiteSessions(id) > 0) throw new ServiceException("场所已有签到场次，请保留资料并使用停用操作");
            count += mapper.deleteSite(id);
        }
        return count;
    }

    private void validateIds(Long[] ids)
    {
        if (ids == null || ids.length == 0 || ids.length > 100) throw new ServiceException("每次请选择1至100条记录");
        for (Long id : ids) requireId(id);
    }

    private void requireId(Long id)
    {
        if (id == null || id <= 0) throw new ServiceException("记录编号不正确");
    }
}
