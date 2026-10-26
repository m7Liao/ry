package com.ruoyi.attendance.service;

import java.util.List;
import org.springframework.stereotype.Service;
import com.ruoyi.attendance.domain.*;
import com.ruoyi.attendance.mapper.AttMapper;
import com.ruoyi.common.annotation.DataScope;
import com.ruoyi.common.core.domain.entity.SysDept;
import com.ruoyi.common.core.domain.entity.SysUser;

/** 独立代理应用数据权限，列表、详情、写入检查和下拉选项使用同一规则。 */
@Service
public class AttScopeService
{
    private final AttMapper mapper;
    public AttScopeService(AttMapper mapper) { this.mapper = mapper; }

    @DataScope(deptAlias = "s")
    public List<AttSite> sites(AttSite query) { return mapper.selectSites(query); }

    @DataScope(deptAlias = "u", userAlias = "e")
    public List<AttEmployee> employees(AttEmployee query) { return mapper.selectEmployees(query); }

    @DataScope(deptAlias = "u", userAlias = "u")
    public List<AttOption> users(SysUser query) { return mapper.selectUsers(query); }

    @DataScope(deptAlias = "d")
    public List<AttOption> departments(SysDept query) { return mapper.selectDepartments(query); }
}
