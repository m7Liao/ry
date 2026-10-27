package com.ruoyi.attendance.service.impl;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Date;
import java.util.Objects;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.attendance.domain.*;
import com.ruoyi.attendance.domain.vo.*;
import com.ruoyi.attendance.mapper.*;
import com.ruoyi.attendance.service.IAttCheckinService;
import com.ruoyi.attendance.support.AttTicketStore;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;

/** 身份来自登录账号；服务端校验场次、档案、绑定关系及凭证。 */
@Service
public class AttCheckinServiceImpl implements IAttCheckinService
{
    private final AttCheckinSessionMapper sessionMapper;
    private final AttCheckinRecordMapper recordMapper;
    private final AttEmployeeMapper employeeMapper;
    private final AttSiteMapper siteMapper;
    private final AttOptionMapper optionMapper;
    private final AttTicketStore tickets;
    private final AttFaceService faceService;

    public AttCheckinServiceImpl(AttCheckinSessionMapper sessionMapper, AttCheckinRecordMapper recordMapper,
            AttEmployeeMapper employeeMapper, AttSiteMapper siteMapper, AttOptionMapper optionMapper, AttTicketStore tickets, AttFaceService faceService)
    {
        this.sessionMapper = sessionMapper;
        this.recordMapper = recordMapper;
        this.employeeMapper = employeeMapper;
        this.siteMapper = siteMapper;
        this.optionMapper = optionMapper;
        this.tickets = tickets;
        this.faceService = faceService;
    }

    @Override
    public AttCheckinIdentityView getIdentity()
    {
        return new AttCheckinIdentityView(currentEmployee(false));
    }

    @Override
    public AttCheckinPreview preview(String ticket)
    {
        AttQrTicket credential = tickets.resolve(ticket);
        AttCheckinSession session = sessionMapper.selectSessionById(credential.getSessionId());
        requireOpen(session);
        AttEmployee employee = currentEmployee(true);
        requireBinding(employee, session);
        AttCheckinRecord existing = recordMapper.selectBySessionEmployee(session.getSessionId(), employee.getEmployeeId());
        AttCheckinPreview view = new AttCheckinPreview();
        view.setSessionId(session.getSessionId());
        view.setTitle(session.getTitle());
        view.setSiteName(employee.getSiteName());
        view.setEmployeeNo(employee.getEmployeeNo());
        view.setEmployeeName(employee.getEmployeeName());
        view.setExpiresAt(credential.getExpiresAt());
        view.setServerTime(System.currentTimeMillis());
        if (existing != null)
        {
            view.setRecordId(existing.getRecordId());
            view.setCheckinTime(existing.getCheckinTime());
        }
        return view;
    }

    @Override
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public AttCheckinResult submit(String ticket)
    {
        return save(ticket, null);
    }

    @Override
    public java.util.Map<String,Object> faceStatus()
    {
        return faceService.myStatus(currentEmployee(false).getEmployeeId());
    }

    @Override
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public AttCheckinResult submitWithFace(String ticket, org.springframework.web.multipart.MultipartFile image)
    {
        if (!faceService.required()) throw new ServiceException("人脸核验尚未启用");
        return save(ticket, image);
    }

    private AttCheckinResult save(String ticket, org.springframework.web.multipart.MultipartFile image)
    {
        AttQrTicket credential = tickets.resolve(ticket);
        // 与关闭场次共用场次行锁，关闭完成后不会再写入新签到。
        AttCheckinSession session = sessionMapper.lockSession(credential.getSessionId());
        requireOpen(session);
        Long userId = SecurityUtils.getUserId();
        AttEmployee locked = employeeMapper.lockEmployeeByUserId(userId);
        if (locked == null) throw new ServiceException("尚未建立员工档案，请联系管理员");
        AttOption account = optionMapper.lockUser(userId);
        if (account == null || !"0".equals(account.getStatus())) throw new ServiceException("账号已停用或删除", 403);
        AttSite site = siteMapper.lockSite(session.getSiteId());
        if (site == null || !"0".equals(site.getStatus())) throw new ServiceException("办公场所已停用");
        AttOption department = optionMapper.lockDepartment(account.getDeptId());
        if (department == null || !"0".equals(department.getStatus())) throw new ServiceException("员工所属部门已停用或删除");
        AttEmployee employee = currentEmployee(true);
        requireBinding(employee, session);
        // 等待行锁期间凭证或场次可能到期，落库前必须再次检查。
        tickets.resolve(ticket);
        requireOpen(session);
        AttCheckinRecord existing = recordMapper.selectBySessionEmployee(session.getSessionId(), employee.getEmployeeId());
        if (existing != null) return result(existing, true);
        AttFaceService.Verification verification = null;
        if (faceService.required())
        {
            if (image == null) throw new ServiceException("当前签到必须完成人脸核验，请使用人脸签到入口");
            verification = faceService.verify(employee.getEmployeeId(), image);
            // 识别耗时不能延长二维码或场次的有效期。
            tickets.resolve(ticket);
            requireOpen(session);
        }
        AttCheckinRecord record = new AttCheckinRecord();
        record.setSessionId(session.getSessionId());
        record.setSessionTitle(session.getTitle());
        record.setEmployeeId(employee.getEmployeeId());
        record.setEmployeeNo(employee.getEmployeeNo());
        record.setEmployeeName(employee.getEmployeeName());
        record.setUserId(userId);
        record.setUserName(employee.getUserName());
        record.setDeptId(employee.getDeptId());
        record.setDeptName(employee.getDeptName());
        record.setSiteId(session.getSiteId());
        record.setSiteName(site.getSiteName());
        record.setCheckinTime(new Date());
        record.setCheckinMethod(verification == null ? "QR" : "QR_FACE");
        recordMapper.insertRecord(record);
        if (verification != null) faceService.saveVerification(record.getRecordId(), verification);
        return result(record, false);
    }

    private AttEmployee currentEmployee(boolean activeRequired)
    {
        AttEmployee employee = employeeMapper.selectEmployeeByUserId(SecurityUtils.getUserId());
        if (employee == null) throw new ServiceException("尚未建立员工档案，请联系管理员");
        if (!"0".equals(employee.getAccountStatus())) throw new ServiceException("账号已停用", 403);
        AttOption department = optionMapper.selectDepartment(employee.getDeptId());
        if (department == null || !"0".equals(department.getStatus())) throw new ServiceException("员工所属部门已停用或删除");
        if (activeRequired)
        {
            if (!"0".equals(employee.getStatus())) throw new ServiceException("员工已离职，无法签到");
            if (employee.getHireDate().isAfter(LocalDate.now(ZoneId.of("Asia/Shanghai")))) throw new ServiceException("尚未到入职日期，无法签到");
            if (!"0".equals(employee.getSiteStatus())) throw new ServiceException("绑定的办公场所已停用");
        }
        return employee;
    }

    private void requireBinding(AttEmployee employee, AttCheckinSession session)
    {
        if (!Objects.equals(employee.getSiteId(), session.getSiteId())) throw new ServiceException("该二维码所属场所与本人绑定场所不一致");
    }

    private void requireOpen(AttCheckinSession session)
    {
        if (session == null || !"0".equals(session.getStatus())) throw new ServiceException("签到场次已关闭或不存在");
        Date now = new Date();
        if (now.before(session.getStartTime()) || !now.before(session.getEndTime())) throw new ServiceException("签到场次已结束或尚未开始");
    }

    private AttCheckinResult result(AttCheckinRecord record, boolean repeated)
    {
        AttCheckinResult result = new AttCheckinResult();
        result.setRecordId(record.getRecordId());
        result.setEmployeeName(record.getEmployeeName());
        result.setSiteName(record.getSiteName());
        result.setCheckinTime(record.getCheckinTime());
        result.setRepeated(repeated);
        return result;
    }
}
