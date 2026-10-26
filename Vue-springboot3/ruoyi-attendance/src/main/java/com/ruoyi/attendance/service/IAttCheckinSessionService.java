package com.ruoyi.attendance.service;

import java.util.List;
import com.ruoyi.attendance.domain.AttCheckinSession;
import com.ruoyi.attendance.domain.dto.AttSessionCreateRequest;
import com.ruoyi.attendance.domain.vo.AttQrCodeView;

/** 签到场次 服务层。 */
public interface IAttCheckinSessionService
{
    List<AttCheckinSession> selectSessionList(AttCheckinSession query);
    AttCheckinSession getSession(Long sessionId);
    AttCheckinSession createSession(AttSessionCreateRequest request);
    int closeSession(Long sessionId);
    AttQrCodeView issueQrCode(Long sessionId);
}
