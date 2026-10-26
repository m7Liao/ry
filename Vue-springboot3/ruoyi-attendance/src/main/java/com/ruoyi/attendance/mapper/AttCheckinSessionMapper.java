package com.ruoyi.attendance.mapper;

import java.util.List;
import com.ruoyi.attendance.domain.AttCheckinSession;

/** 签到场次 数据访问层。 */
public interface AttCheckinSessionMapper
{
    List<AttCheckinSession> selectSessionList(AttCheckinSession query);
    AttCheckinSession selectSessionById(Long sessionId);
    AttCheckinSession lockSession(Long sessionId);
    int insertSession(AttCheckinSession session);
    int closeSession(AttCheckinSession session);
    int countSiteSessions(Long siteId);
}
