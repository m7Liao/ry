package com.ruoyi.attendance.service;

import java.util.Arrays;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import com.ruoyi.attendance.mapper.AttMapper;
import com.ruoyi.common.event.BeforeSystemDelete;
import com.ruoyi.common.exception.ServiceException;

/** 与新建绑定使用同一父行锁，防止删除检查与绑定操作并发产生悬空引用。 */
@Component
public class AttReferenceGuard
{
    private final AttMapper mapper;
    public AttReferenceGuard(AttMapper mapper) { this.mapper = mapper; }

    @EventListener
    public void beforeDelete(BeforeSystemDelete event)
    {
        for (Long id : Arrays.stream(event.ids()).distinct().sorted().toList()) {
            if (event.target() == BeforeSystemDelete.Target.USER) {
                mapper.lockUser(id);
                if (mapper.countUserEmployees(id) > 0) throw new ServiceException("账号关联员工档案，请先删除员工档案；离职请维护员工状态并停用账号");
            } else {
                mapper.lockDepartment(id);
                if (mapper.countDepartmentSites(id) > 0) throw new ServiceException("部门关联办公场所，请先调整场所的管理部门");
            }
        }
    }
}
