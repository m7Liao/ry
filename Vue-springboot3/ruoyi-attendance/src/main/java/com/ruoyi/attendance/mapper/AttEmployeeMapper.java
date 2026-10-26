package com.ruoyi.attendance.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.attendance.domain.*;
import com.ruoyi.common.core.domain.entity.SysDept;
import com.ruoyi.common.core.domain.entity.SysUser;

/** 员工档案 数据访问层。 */
public interface AttEmployeeMapper
{
    AttEmployee selectEmployeeByUserId(Long userId);
    AttEmployee lockEmployeeByUserId(Long userId);
    List<AttEmployee> selectEmployees(AttEmployee query);
    List<AttOption> selectUsers(SysUser query);
    AttEmployee lockEmployee(Long id);
    int insertEmployee(AttEmployee employee);
    int updateEmployee(AttEmployee employee);
    int deleteEmployee(Long id);
    int countUserEmployees(Long id);
    int countDuplicateEmployee(@Param("no") String no, @Param("userId") Long userId, @Param("id") Long id);
}
