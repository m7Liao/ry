package com.ruoyi.attendance.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.attendance.domain.AttCheckinRecord;

/** 原始签到记录 数据访问层。 */
public interface AttCheckinRecordMapper
{
    List<AttCheckinRecord> selectRecordList(AttCheckinRecord query);
    List<AttCheckinRecord> selectMyRecordList(AttCheckinRecord query);
    AttCheckinRecord selectBySessionEmployee(@Param("sessionId") Long sessionId, @Param("employeeId") Long employeeId);
    int insertRecord(AttCheckinRecord record);
    int countEmployeeRecords(Long employeeId);
}
