package com.ruoyi.attendance.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.attendance.domain.*;
import com.ruoyi.common.core.domain.entity.SysDept;
import com.ruoyi.common.core.domain.entity.SysUser;

public interface AttMapper
{
    List<AttSite> selectSites(AttSite query);
    List<AttEmployee> selectEmployees(AttEmployee query);
    List<AttOption> selectUsers(SysUser query);
    List<AttOption> selectDepartments(SysDept query);
    AttSite lockSite(Long id);
    AttEmployee lockEmployee(Long id);
    AttOption lockUser(Long id);
    AttOption lockDepartment(Long id);
    int insertSite(AttSite site);
    int updateSite(AttSite site);
    int deleteSite(Long id);
    int insertEmployee(AttEmployee employee);
    int updateEmployee(AttEmployee employee);
    int deleteEmployee(Long id);
    int countSiteEmployees(Long id);
    int countUserEmployees(Long id);
    int countDepartmentSites(Long id);
    int countDuplicateSite(@Param("code") String code, @Param("id") Long id);
    int countDuplicateEmployee(@Param("no") String no, @Param("userId") Long userId, @Param("id") Long id);
}
