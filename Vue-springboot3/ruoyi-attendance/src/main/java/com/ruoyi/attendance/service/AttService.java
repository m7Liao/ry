package com.ruoyi.attendance.service;

import java.util.Arrays;
import java.util.List;
import java.util.Objects;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.Isolation;
import com.ruoyi.attendance.domain.*;
import com.ruoyi.attendance.mapper.AttMapper;
import com.ruoyi.common.core.domain.entity.SysDept;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;

@Service
public class AttService
{
    private final AttMapper mapper;
    private final AttScopeService scope;
    public AttService(AttMapper mapper, AttScopeService scope) { this.mapper = mapper; this.scope = scope; }

    public AttSite site(Long id)
    {
        AttSite query = new AttSite(); query.setSiteId(id);
        List<AttSite> rows = scope.sites(query);
        if (rows.isEmpty()) throw new ServiceException("场所不存在或无权访问", 403);
        return rows.get(0);
    }

    public AttEmployee employee(Long id)
    {
        AttEmployee query = new AttEmployee(); query.setEmployeeId(id);
        List<AttEmployee> rows = scope.employees(query);
        if (rows.isEmpty()) throw new ServiceException("员工档案不存在或无权访问", 403);
        return rows.get(0);
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public int saveSite(AttSite site, boolean edit)
    {
        if (edit) {
            requireId(site.getSiteId());
            if (mapper.lockSite(site.getSiteId()) == null) throw new ServiceException("场所已被删除");
            site(site.getSiteId());
        } else site.setSiteId(null);
        SysDept dept = new SysDept(); dept.setDeptId(site.getDeptId());
        AttOption lockedDept = mapper.lockDepartment(site.getDeptId());
        if (lockedDept == null || !"0".equals(lockedDept.getStatus())) throw new ServiceException("管理部门已停用或删除");
        if (scope.departments(dept).isEmpty()) throw new ServiceException("管理部门不存在、已停用或无权访问", 403);
        site.setSiteName(site.getSiteName().trim());
        site.setAddress(site.getAddress().trim());
        if ((site.getLongitude() == null) != (site.getLatitude() == null)) throw new ServiceException("经度和纬度必须同时填写或同时留空");
        if (mapper.countDuplicateSite(site.getSiteCode(), site.getSiteId()) > 0) throw new ServiceException("场所编码已存在");
        if (edit) { site.setUpdateBy(SecurityUtils.getUsername()); return mapper.updateSite(site); }
        site.setCreateBy(SecurityUtils.getUsername()); return mapper.insertSite(site);
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public int saveEmployee(AttEmployee employee, boolean edit)
    {
        AttEmployee previous = null;
        if (edit) {
            requireId(employee.getEmployeeId());
            previous = mapper.lockEmployee(employee.getEmployeeId());
            if (previous == null) throw new ServiceException("员工档案已被删除");
            employee(employee.getEmployeeId());
            if (!Objects.equals(previous.getUserId(), employee.getUserId())) throw new ServiceException("已有档案不能更换系统账号");
        } else {
            employee.setEmployeeId(null);
        }
        AttOption user = mapper.lockUser(employee.getUserId());
        if (user == null) throw new ServiceException("关联账号已被删除");
        if (edit) employee(employee.getEmployeeId());
        else {
            SysUser query = new SysUser(); query.setUserId(employee.getUserId());
            if (scope.users(query).isEmpty()) throw new ServiceException("账号已绑定、已停用、部门停用或无权访问", 403);
        }
        if (!edit && !"0".equals(user.getStatus())) throw new ServiceException("不能绑定停用的账号");
        // 保留原停用场所允许维护历史档案，更换绑定时必须通过场所数据权限和启用检查。
        boolean changedSite = previous == null || !Objects.equals(previous.getSiteId(), employee.getSiteId());
        AttSite target = mapper.lockSite(employee.getSiteId());
        if (target == null) throw new ServiceException("办公场所已被删除");
        if (changedSite) site(employee.getSiteId());
        if (changedSite && !"0".equals(target.getStatus())) throw new ServiceException("不能绑定停用的办公场所");
        if (employee.getLeaveDate() != null && employee.getLeaveDate().isBefore(employee.getHireDate())) throw new ServiceException("离职日期不能早于入职日期");
        if ("1".equals(employee.getStatus()) && employee.getLeaveDate() == null) throw new ServiceException("离职员工必须填写离职日期");
        if ("0".equals(employee.getStatus()) && employee.getLeaveDate() != null) throw new ServiceException("在职员工不能填写离职日期");
        if (mapper.countDuplicateEmployee(employee.getEmployeeNo(), employee.getUserId(), employee.getEmployeeId()) > 0) throw new ServiceException("工号已存在或系统账号已绑定其他档案");
        employee.setEmployeeName(employee.getEmployeeName().trim());
        if (edit) { employee.setUpdateBy(SecurityUtils.getUsername()); return mapper.updateEmployee(employee); }
        employee.setCreateBy(SecurityUtils.getUsername()); return mapper.insertEmployee(employee);
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public int deleteSites(Long[] ids)
    {
        validateIds(ids);
        int count = 0;
        for (Long id : Arrays.stream(ids).distinct().sorted().toList()) {
            if (mapper.lockSite(id) == null) throw new ServiceException("场所已被删除");
            site(id);
            if (mapper.countSiteEmployees(id) > 0) throw new ServiceException("场所仍绑定员工，请先修改或删除员工档案");
            count += mapper.deleteSite(id);
        }
        return count;
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public int deleteEmployees(Long[] ids)
    {
        validateIds(ids);
        int count = 0;
        for (Long id : Arrays.stream(ids).distinct().sorted().toList()) {
            AttEmployee locked = mapper.lockEmployee(id);
            if (locked == null) throw new ServiceException("员工档案已被删除");
            mapper.lockUser(locked.getUserId());
            employee(id);
            count += mapper.deleteEmployee(id);
        }
        return count;
    }

    private void validateIds(Long[] ids) {
        if (ids == null || ids.length == 0 || ids.length > 100) throw new ServiceException("每次请选择1至100条记录");
        for (Long id : ids) requireId(id);
    }
    private void requireId(Long id) { if (id == null || id <= 0) throw new ServiceException("记录编号不正确"); }
}
