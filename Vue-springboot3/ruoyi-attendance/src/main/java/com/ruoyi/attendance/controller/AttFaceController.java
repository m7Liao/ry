package com.ruoyi.attendance.controller;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import com.ruoyi.attendance.service.impl.AttFaceService;
import com.ruoyi.attendance.service.IAttCheckinRecordService;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.annotation.RateLimiter;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.common.enums.LimitType;
@RestController
@RequestMapping("/attendance/face")
public class AttFaceController extends BaseController {
    private final AttFaceService service;
    private final IAttCheckinRecordService records;
    public AttFaceController(AttFaceService service,IAttCheckinRecordService records) { this.service=service; this.records=records; }
    @PreAuthorize("@ss.hasPermi('attendance:face:query')")
    @GetMapping("/{employeeId}")
    public AjaxResult status(@PathVariable Long employeeId) { return success(service.profileStatus(employeeId)); }
    @PreAuthorize("@ss.hasPermi('attendance:face:enroll')")
    @Log(title="员工人脸录入",businessType=BusinessType.UPDATE,isSaveRequestData=false,isSaveResponseData=false)
    @RateLimiter(time=60,count=30,limitType=LimitType.IP)
    @PostMapping(value="/{employeeId}",consumes="multipart/form-data")
    public AjaxResult enroll(@PathVariable Long employeeId,@RequestParam MultipartFile image,@RequestParam boolean consent) {
        service.enroll(employeeId,image,consent); return success();
    }
    @PreAuthorize("@ss.hasPermi('attendance:face:remove')")
    @Log(title="员工人脸撤销",businessType=BusinessType.DELETE,isSaveRequestData=false)
    @DeleteMapping("/{employeeId}")
    public AjaxResult remove(@PathVariable Long employeeId) { service.remove(employeeId); return success(); }
    @PreAuthorize("@ss.hasPermi('attendance:record:query')")
    @GetMapping("/record/{recordId}")
    public AjaxResult record(@PathVariable Long recordId) { records.getRecord(recordId); return success(service.verification(recordId)); }
}
