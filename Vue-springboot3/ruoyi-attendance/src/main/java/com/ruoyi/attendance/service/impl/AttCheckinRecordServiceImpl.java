package com.ruoyi.attendance.service.impl;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.List;
import org.springframework.stereotype.Service;
import com.ruoyi.attendance.domain.AttCheckinRecord;
import com.ruoyi.attendance.mapper.AttCheckinRecordMapper;
import com.ruoyi.attendance.service.IAttCheckinRecordService;
import com.ruoyi.common.annotation.DataScope;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.common.utils.spring.SpringUtils;

@Service
public class AttCheckinRecordServiceImpl implements IAttCheckinRecordService
{
    private final AttCheckinRecordMapper mapper;

    public AttCheckinRecordServiceImpl(AttCheckinRecordMapper mapper)
    {
        this.mapper = mapper;
    }

    @Override
    @DataScope(deptAlias = "r", userAlias = "r")
    public List<AttCheckinRecord> selectRecordList(AttCheckinRecord query)
    {
        validateDates(query);
        return mapper.selectRecordList(query);
    }

    @Override
    public AttCheckinRecord getRecord(Long recordId)
    {
        AttCheckinRecord query = new AttCheckinRecord();
        query.setRecordId(recordId);
        List<AttCheckinRecord> rows = SpringUtils.getAopProxy(this).selectRecordList(query);
        if (rows.isEmpty()) throw new ServiceException("签到记录不存在或无权访问", 403);
        return rows.get(0);
    }

    @Override
    public List<AttCheckinRecord> selectMyRecordList(AttCheckinRecord query)
    {
        // 必须来自当前登录身份，忽略客户端传入的 userId 和数据范围。
        query.setUserId(SecurityUtils.getUserId());
        validateDates(query);
        return mapper.selectMyRecordList(query);
    }

    private void validateDates(AttCheckinRecord query)
    {
        try
        {
            LocalDate begin = StringUtils.isBlank(query.getBeginDate()) ? null : LocalDate.parse(query.getBeginDate());
            LocalDate end = StringUtils.isBlank(query.getEndDate()) ? null : LocalDate.parse(query.getEndDate());
            if (begin != null && end != null && begin.isAfter(end)) throw new ServiceException("开始日期不能晚于结束日期");
        }
        catch (DateTimeParseException e)
        {
            throw new ServiceException("日期格式不正确，请使用有效的 yyyy-MM-dd 日期");
        }
    }
}
