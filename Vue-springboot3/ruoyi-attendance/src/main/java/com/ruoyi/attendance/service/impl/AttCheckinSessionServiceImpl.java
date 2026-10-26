package com.ruoyi.attendance.service.impl;

import java.util.Date;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.attendance.domain.AttCheckinSession;
import com.ruoyi.attendance.domain.AttSite;
import com.ruoyi.attendance.domain.dto.AttSessionCreateRequest;
import com.ruoyi.attendance.domain.vo.AttQrCodeView;
import com.ruoyi.attendance.mapper.AttCheckinSessionMapper;
import com.ruoyi.attendance.mapper.AttSiteMapper;
import com.ruoyi.attendance.service.IAttCheckinSessionService;
import com.ruoyi.attendance.service.IAttSiteService;
import com.ruoyi.attendance.support.AttTicketStore;
import com.ruoyi.common.annotation.DataScope;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.spring.SpringUtils;

/** 签到场次 服务层实现。 */
@Service
public class AttCheckinSessionServiceImpl implements IAttCheckinSessionService
{
    private final AttCheckinSessionMapper mapper;
    private final AttSiteMapper siteMapper;
    private final IAttSiteService siteService;
    private final AttTicketStore tickets;

    public AttCheckinSessionServiceImpl(AttCheckinSessionMapper mapper, AttSiteMapper siteMapper,
            IAttSiteService siteService, AttTicketStore tickets)
    {
        this.mapper = mapper;
        this.siteMapper = siteMapper;
        this.siteService = siteService;
        this.tickets = tickets;
    }

    @Override
    @DataScope(deptAlias = "c")
    public List<AttCheckinSession> selectSessionList(AttCheckinSession query)
    {
        return mapper.selectSessionList(query);
    }

    @Override
    public AttCheckinSession getSession(Long sessionId)
    {
        AttCheckinSession query = new AttCheckinSession();
        query.setSessionId(sessionId);
        List<AttCheckinSession> rows = SpringUtils.getAopProxy(this).selectSessionList(query);
        if (rows.isEmpty()) throw new ServiceException("场次不存在或无权访问", 403);
        return rows.get(0);
    }

    @Override
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public AttCheckinSession createSession(AttSessionCreateRequest request)
    {
        AttSite locked = siteMapper.lockSite(request.getSiteId());
        if (locked == null || !"0".equals(locked.getStatus())) throw new ServiceException("场所不存在或已停用");
        siteService.getSite(request.getSiteId());
        Date now = new Date();
        AttCheckinSession session = new AttCheckinSession();
        session.setSiteId(locked.getSiteId());
        session.setDeptId(locked.getDeptId());
        session.setTitle(request.getTitle().trim());
        session.setStartTime(now);
        session.setEndTime(new Date(now.getTime() + request.getDurationMinutes() * 60_000L));
        session.setStatus("0");
        session.setCreateBy(SecurityUtils.getUsername());
        mapper.insertSession(session);
        session.setSiteName(locked.getSiteName());
        return session;
    }

    @Override
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public int closeSession(Long sessionId)
    {
        AttCheckinSession session = mapper.lockSession(sessionId);
        if (session == null) throw new ServiceException("场次不存在或无权访问", 403);
        getSession(sessionId);
        session.setUpdateBy(SecurityUtils.getUsername());
        return mapper.closeSession(session);
    }

    @Override
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public AttQrCodeView issueQrCode(Long sessionId)
    {
        AttCheckinSession session = mapper.lockSession(sessionId);
        if (session == null) throw new ServiceException("场次不存在或无权访问", 403);
        getSession(sessionId);
        requireOpen(session);
        AttSite site = siteMapper.lockSite(session.getSiteId());
        if (site == null || !"0".equals(site.getStatus())) throw new ServiceException("办公场所已停用");
        siteService.getSite(site.getSiteId());
        session.setSiteName(site.getSiteName());
        return tickets.issue(session);
    }

    private void requireOpen(AttCheckinSession session)
    {
        Date now = new Date();
        if (!"0".equals(session.getStatus())) throw new ServiceException("签到场次已关闭");
        if (now.before(session.getStartTime()) || !now.before(session.getEndTime())) throw new ServiceException("当前不在签到场次有效时间内");
    }
}
