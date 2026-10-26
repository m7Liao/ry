package com.ruoyi.attendance.service;

import java.util.List;
import com.ruoyi.attendance.domain.AttCheckinRecord;

/** 原始签到记录 查询服务。 */
public interface IAttCheckinRecordService
{
    List<AttCheckinRecord> selectRecordList(AttCheckinRecord query);
    AttCheckinRecord getRecord(Long recordId);
    List<AttCheckinRecord> selectMyRecordList(AttCheckinRecord query);
}
