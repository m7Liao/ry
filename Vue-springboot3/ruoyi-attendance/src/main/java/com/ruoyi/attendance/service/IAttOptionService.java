package com.ruoyi.attendance.service;
import java.util.List;
import com.ruoyi.attendance.domain.AttOption;
import com.ruoyi.common.core.domain.entity.SysDept;

/** 基础资料选择服务。 */
public interface IAttOptionService
{
    List<AttOption> selectDepartmentOptions(SysDept query);
}
