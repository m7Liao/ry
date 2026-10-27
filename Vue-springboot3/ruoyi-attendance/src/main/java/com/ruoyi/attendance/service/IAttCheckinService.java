package com.ruoyi.attendance.service;

import com.ruoyi.attendance.domain.vo.AttCheckinIdentityView;
import com.ruoyi.attendance.domain.vo.AttCheckinPreview;
import com.ruoyi.attendance.domain.vo.AttCheckinResult;

/** 登录员工扫码签到 服务层。 */
public interface IAttCheckinService
{
    AttCheckinIdentityView getIdentity();
    AttCheckinPreview preview(String ticket);
    AttCheckinResult submit(String ticket);
    AttCheckinResult submitWithFace(String ticket, org.springframework.web.multipart.MultipartFile image);
    java.util.Map<String,Object> faceStatus();
}
