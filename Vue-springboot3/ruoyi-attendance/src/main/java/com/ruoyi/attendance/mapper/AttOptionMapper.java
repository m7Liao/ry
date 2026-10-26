package com.ruoyi.attendance.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.attendance.domain.*;
import com.ruoyi.common.core.domain.entity.SysDept;
import com.ruoyi.common.core.domain.entity.SysUser;

/** 基础选择项及关联行锁 数据访问层。 */
public interface AttOptionMapper
{
    AttOption selectUser(Long id);
    AttOption selectDepartment(Long id);
    List<AttOption> selectDepartments(SysDept query);
    AttOption lockUser(Long id);
    AttOption lockDepartment(Long id);
}
