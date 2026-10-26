package com.ruoyi.attendance.service;

import java.util.List;
import com.ruoyi.attendance.domain.*;
import com.ruoyi.common.core.domain.entity.SysUser;

/** 员工档案 服务层。 */
public interface IAttEmployeeService
{
    List<AttEmployee> selectEmployeeList(AttEmployee query);
    List<AttOption> selectUserOptions(SysUser query);
    AttEmployee getEmployee(Long id);
    int saveEmployee(AttEmployee employee, boolean edit);
    int deleteEmployees(Long[] ids);
}
