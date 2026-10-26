package com.ruoyi.attendance.service;

import java.util.List;
import com.ruoyi.attendance.domain.*;
import com.ruoyi.common.core.domain.entity.SysUser;

/** 办公场所 服务层。 */
public interface IAttSiteService
{
    List<AttSite> selectSiteList(AttSite query);
    AttSite getSite(Long id);
    int saveSite(AttSite site, boolean edit);
    int deleteSites(Long[] ids);
}
