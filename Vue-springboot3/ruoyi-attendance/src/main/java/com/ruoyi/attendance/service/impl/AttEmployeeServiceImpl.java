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

/** 员工档案与绑定 服务层实现。 */
@Service
public class AttEmployeeServiceImpl implements IAttEmployeeService
{
    private final AttEmployeeMapper mapper;
    private final AttOptionMapper optionMapper;
    private final AttSiteMapper siteMapper;
    private final IAttSiteService siteService;
    private final AttCheckinRecordMapper recordMapper;
    private final AttDailyMapper dailyMapper;
    public AttEmployeeServiceImpl(AttEmployeeMapper mapper, AttOptionMapper optionMapper,
            AttSiteMapper siteMapper, IAttSiteService siteService, AttCheckinRecordMapper recordMapper, AttDailyMapper dailyMapper)
    {
        this.mapper = mapper;
        this.optionMapper = optionMapper;
        this.siteMapper = siteMapper;
        this.siteService = siteService;
        this.recordMapper = recordMapper;
        this.dailyMapper = dailyMapper;
    }

    @Override
    @DataScope(deptAlias = "u", userAlias = "e")
    public List<AttEmployee> selectEmployeeList(AttEmployee query)
    {
        return mapper.selectEmployees(query);
    }

    @Override
    @DataScope(deptAlias = "u", userAlias = "u")
    public List<AttOption> selectUserOptions(SysUser query)
    {
        return mapper.selectUsers(query);
    }

    @Override
    public AttEmployee getEmployee(Long id)
    {
        AttEmployee query = new AttEmployee(); query.setEmployeeId(id);
        List<AttEmployee> rows = SpringUtils.getAopProxy(this).selectEmployeeList(query);
        if (rows.isEmpty()) throw new ServiceException("员工档案不存在或无权访问", 403);
        return rows.get(0);
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    @Override
    public int saveEmployee(AttEmployee employee, boolean edit)
    {
        AttEmployee previous = null;
        if (edit) {
            requireId(employee.getEmployeeId());
            previous = mapper.lockEmployee(employee.getEmployeeId());
            if (previous == null) throw new ServiceException("员工档案已被删除");
            getEmployee(employee.getEmployeeId());
            if (!Objects.equals(previous.getUserId(), employee.getUserId())) throw new ServiceException("已有档案不能更换系统账号");
        } else {
            employee.setEmployeeId(null);
        }
        AttOption user = optionMapper.lockUser(employee.getUserId());
        if (user == null) throw new ServiceException("关联账号已被删除");
        if (edit) getEmployee(employee.getEmployeeId());
        else {
            SysUser query = new SysUser(); query.setUserId(employee.getUserId());
            if (SpringUtils.getAopProxy(this).selectUserOptions(query).isEmpty()) throw new ServiceException("账号已绑定、已停用、部门停用或无权访问", 403);
        }
        if (!edit && !"0".equals(user.getStatus())) throw new ServiceException("不能绑定停用的账号");
        // 保留原停用场所允许维护历史档案，更换绑定时必须通过场所数据权限和启用检查。
        boolean changedSite = previous == null || !Objects.equals(previous.getSiteId(), employee.getSiteId());
        AttSite target = siteMapper.lockSite(employee.getSiteId());
        if (target == null) throw new ServiceException("办公场所已被删除");
        if (changedSite) siteService.getSite(employee.getSiteId());
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
    @Override
    public int deleteEmployees(Long[] ids)
    {
        validateIds(ids);
        int count = 0;
        for (Long id : Arrays.stream(ids).distinct().sorted().toList()) {
            AttEmployee locked = mapper.lockEmployee(id);
            if (locked == null) throw new ServiceException("员工档案已被删除");
            optionMapper.lockUser(locked.getUserId());
            getEmployee(id);
            if (dailyMapper.countEmployeeResults(id) > 0) throw new ServiceException("员工已有每日考勤结果，请保留档案并维护离职状态");
            if (recordMapper.countEmployeeRecords(id) > 0) throw new ServiceException("员工已有签到记录，请保留档案并维护离职状态");
            count += mapper.deleteEmployee(id);
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
