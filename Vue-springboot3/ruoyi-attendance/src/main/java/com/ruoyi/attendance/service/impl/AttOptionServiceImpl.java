package com.ruoyi.attendance.service.impl;
import java.util.List;
import org.springframework.stereotype.Service;
import com.ruoyi.attendance.domain.AttOption;
import com.ruoyi.attendance.mapper.AttOptionMapper;
import com.ruoyi.attendance.service.IAttOptionService;
import com.ruoyi.common.annotation.DataScope;
import com.ruoyi.common.core.domain.entity.SysDept;

@Service
public class AttOptionServiceImpl implements IAttOptionService
{
    private final AttOptionMapper mapper;
    public AttOptionServiceImpl(AttOptionMapper mapper) { this.mapper = mapper; }

    @Override
    @DataScope(deptAlias = "d")
    public List<AttOption> selectDepartmentOptions(SysDept query)
    {
        return mapper.selectDepartments(query);
    }
}
