package com.ruoyi.attendance.service.impl;

import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import com.ruoyi.attendance.domain.*;
import com.ruoyi.attendance.mapper.*;
import com.ruoyi.attendance.service.IAttEmployeeService;
import com.ruoyi.attendance.support.*;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;

@Service
public class AttFaceService {
    private final AttFaceProperties properties;
    private final AttArcsoftEngine engine;
    private final AttFaceCipher cipher;
    private final AttFaceMapper mapper;
    private final AttEmployeeMapper employees;
    private final IAttEmployeeService employeeService;
    public record Verification(double score,double threshold,long version,String model) { }
    public AttFaceService(AttFaceProperties p,AttArcsoftEngine e,AttFaceCipher c,AttFaceMapper m,AttEmployeeMapper employees,IAttEmployeeService service) {
        properties=p; engine=e; cipher=c; mapper=m; this.employees=employees; employeeService=service;
    }
    public boolean required() { return properties.isEnabled(); }
    public Map<String,Object> engineStatus() {
        Map<String,Object> status=new LinkedHashMap<>(); status.put("required",required()); status.put("ready",false);
        if (!required()) { status.put("message","当前为普通扫码签到，未启用人脸核验"); return status; }
        try { cipher.validate(); engine.requireReady(); status.put("ready",true); status.put("message","虹软引擎已就绪"); }
        catch (ServiceException e) { status.put("message",e.getMessage()); }
        return status;
    }
    public Map<String,Object> profileStatus(Long employeeId) {
        employeeService.getEmployee(employeeId);
        Map<String,Object> result=engineStatus();
        AttFaceProfile profile=mapper.selectProfile(employeeId);
        result.put("enrolled",profile!=null);
        if (profile!=null) { result.put("version",profile.getVersion()); result.put("updatedTime",profile.getUpdatedTime()); result.put("model",profile.getModel()); }
        return result;
    }
    public Map<String,Object> myStatus(Long employeeId) {
        Map<String,Object> result=engineStatus(); result.put("enrolled",mapper.selectProfile(employeeId)!=null); return result;
    }
    @Transactional
    public void enroll(Long employeeId,MultipartFile image,boolean consent) {
        if (!consent) throw new ServiceException("请确认员工知情同意后再录入人脸");
        AttEmployee employee=employees.lockEmployee(employeeId);
        if (employee==null) throw new ServiceException("员工档案不存在");
        employeeService.getEmployee(employeeId);
        if (!"0".equals(employee.getStatus())) throw new ServiceException("离职员工不能录入人脸");
        byte[] feature=engine.extract(AttFaceImage.read(image));
        AttFaceProfile profile=new AttFaceProfile(); profile.setEmployeeId(employeeId);
        profile.setModel(AttArcsoftEngine.MODEL); profile.setEncryptedFeature(cipher.encrypt(employeeId,feature));
        java.util.Arrays.fill(feature,(byte)0);
        profile.setUpdatedBy(SecurityUtils.getUsername()); mapper.saveProfile(profile);
    }
    @Transactional
    public void remove(Long employeeId) {
        if (employees.lockEmployee(employeeId)==null) throw new ServiceException("员工档案不存在");
        employeeService.getEmployee(employeeId); mapper.deleteProfile(employeeId);
    }
    /** 调用者持有员工行锁；录入/撤销与签到按相同员工行锁串行。 */
    public Verification verify(Long employeeId,MultipartFile image) {
        if (!required()) throw new ServiceException("当前尚未启用人脸核验");
        AttFaceProfile profile=mapper.selectProfile(employeeId);
        if (profile==null) throw new ServiceException("本人尚未录入人脸，请联系管理员");
        if (!AttArcsoftEngine.MODEL.equals(profile.getModel())) throw new ServiceException("人脸模型版本不匹配，请重新录入");
        byte[] enrolled=cipher.decrypt(employeeId,profile.getEncryptedFeature()), probe=null;
        try {
            probe=engine.extract(AttFaceImage.read(image));
            double score=engine.compare(enrolled,probe);
            if (score<properties.getThreshold()) throw new ServiceException("人脸与本人档案不匹配，请重新采集或联系管理员");
            return new Verification(score,properties.getThreshold(),profile.getVersion(),profile.getModel());
        } finally { java.util.Arrays.fill(enrolled,(byte)0); if (probe!=null) java.util.Arrays.fill(probe,(byte)0); }
    }
    public void saveVerification(Long recordId,Verification v) { mapper.insertVerification(recordId,v.score(),v.threshold(),v.version(),v.model()); }
    public Map<String,Object> verification(Long recordId) { return mapper.selectVerification(recordId); }
}
