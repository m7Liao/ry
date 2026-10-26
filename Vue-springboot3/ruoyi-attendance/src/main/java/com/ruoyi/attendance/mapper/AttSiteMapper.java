package com.ruoyi.attendance.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.attendance.domain.*;
import com.ruoyi.common.core.domain.entity.SysDept;
import com.ruoyi.common.core.domain.entity.SysUser;

/** 办公场所 数据访问层。 */
public interface AttSiteMapper
{
    List<AttSite> selectSites(AttSite query);
    AttSite lockSite(Long id);
    int insertSite(AttSite site);
    int updateSite(AttSite site);
    int deleteSite(Long id);
    int countSiteEmployees(Long id);
    int countDepartmentSites(Long id);
    int countDuplicateSite(@Param("code") String code, @Param("id") Long id);
}
