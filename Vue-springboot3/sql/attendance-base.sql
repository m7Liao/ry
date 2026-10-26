-- 在已初始化的 ry-vue 数据库执行。本脚本不清空现有数据，可重复执行。
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS att_site (
    site_id BIGINT NOT NULL AUTO_INCREMENT COMMENT '场所ID',
    site_code VARCHAR(32) NOT NULL COMMENT '全局唯一场所编码',
    site_name VARCHAR(100) NOT NULL COMMENT '场所名称',
    dept_id BIGINT NOT NULL COMMENT '管理部门，决定数据范围',
    address VARCHAR(255) NOT NULL COMMENT '详细地址',
    longitude DECIMAL(9,6) DEFAULT NULL COMMENT '经度',
    latitude DECIMAL(8,6) DEFAULT NULL COMMENT '纬度',
    coordinate_system VARCHAR(10) NOT NULL DEFAULT 'GCJ02' COMMENT '坐标系，不自动转换',
    contact_name VARCHAR(50) DEFAULT NULL,
    contact_phone VARCHAR(30) DEFAULT NULL,
    status CHAR(1) NOT NULL DEFAULT '0' COMMENT '0启用 1停用',
    remark VARCHAR(500) DEFAULT NULL,
    create_by VARCHAR(64) DEFAULT '', create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by VARCHAR(64) DEFAULT '', update_time DATETIME DEFAULT NULL,
    PRIMARY KEY (site_id), UNIQUE KEY uk_att_site_code (site_code), KEY idx_att_site_dept (dept_id),
    CONSTRAINT fk_att_site_dept FOREIGN KEY (dept_id) REFERENCES sys_dept(dept_id),
    CONSTRAINT ck_att_site_status CHECK (status IN ('0','1')),
    CONSTRAINT ck_att_site_coordinates CHECK ((longitude IS NULL AND latitude IS NULL) OR
        (longitude IS NOT NULL AND latitude IS NOT NULL AND longitude BETWEEN -180 AND 180 AND latitude BETWEEN -90 AND 90)),
    CONSTRAINT ck_att_site_crs CHECK (coordinate_system IN ('GCJ02','WGS84','BD09'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='办公场所';

CREATE TABLE IF NOT EXISTS att_employee (
    employee_id BIGINT NOT NULL AUTO_INCREMENT COMMENT '档案ID',
    employee_no VARCHAR(32) NOT NULL COMMENT '全局唯一工号',
    employee_name VARCHAR(50) NOT NULL COMMENT '员工姓名',
    user_id BIGINT NOT NULL COMMENT '一对一关联账号，部门取账号当前部门',
    site_id BIGINT NOT NULL COMMENT '主要办公场所',
    phone VARCHAR(30) DEFAULT NULL, email VARCHAR(100) DEFAULT NULL,
    hire_date DATE NOT NULL, leave_date DATE DEFAULT NULL,
    status CHAR(1) NOT NULL DEFAULT '0' COMMENT '0在职 1离职，与账号状态分开维护',
    remark VARCHAR(500) DEFAULT NULL,
    create_by VARCHAR(64) DEFAULT '', create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by VARCHAR(64) DEFAULT '', update_time DATETIME DEFAULT NULL,
    PRIMARY KEY (employee_id), UNIQUE KEY uk_att_employee_no (employee_no),
    UNIQUE KEY uk_att_employee_user (user_id), KEY idx_att_employee_site (site_id),
    CONSTRAINT fk_att_employee_user FOREIGN KEY (user_id) REFERENCES sys_user(user_id),
    CONSTRAINT fk_att_employee_site FOREIGN KEY (site_id) REFERENCES att_site(site_id),
    CONSTRAINT ck_att_employee_dates CHECK (leave_date IS NULL OR leave_date >= hire_date),
    CONSTRAINT ck_att_employee_status CHECK ((status='0' AND leave_date IS NULL) OR (status='1' AND leave_date IS NOT NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='员工业务档案';

START TRANSACTION;
INSERT INTO sys_menu(menu_name,parent_id,order_num,path,component,is_frame,is_cache,menu_type,visible,status,perms,icon,create_by,create_time)
SELECT '考勤管理',0,4,'attendance',NULL,1,0,'M','0','0','','peoples','admin',NOW()
WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE parent_id=0 AND path='attendance');
SET @att_root = (SELECT menu_id FROM sys_menu WHERE parent_id=0 AND path='attendance' LIMIT 1);

INSERT INTO sys_menu(menu_name,parent_id,order_num,path,component,route_name,is_frame,is_cache,menu_type,visible,status,perms,icon,create_by,create_time)
SELECT '办公场所',@att_root,1,'site','attendance/site/index','AttendanceSite',1,1,'C','0','0','attendance:site:list','build','admin',NOW()
WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='attendance:site:list');
INSERT INTO sys_menu(menu_name,parent_id,order_num,path,component,route_name,is_frame,is_cache,menu_type,visible,status,perms,icon,create_by,create_time)
SELECT '员工档案',@att_root,2,'employee','attendance/employee/index','AttendanceEmployee',1,1,'C','0','0','attendance:employee:list','user','admin',NOW()
WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='attendance:employee:list');
SET @att_site = (SELECT menu_id FROM sys_menu WHERE perms='attendance:site:list' LIMIT 1);
SET @att_employee = (SELECT menu_id FROM sys_menu WHERE perms='attendance:employee:list' LIMIT 1);

INSERT INTO sys_menu(menu_name,parent_id,order_num,path,is_frame,is_cache,menu_type,visible,status,perms,icon,create_by,create_time)
SELECT actions.label, pages.id, actions.num, '#',1,0,'F','0','0',CONCAT(pages.prefix,actions.action),'#','admin',NOW()
FROM (SELECT @att_site id,'attendance:site:' prefix UNION ALL SELECT @att_employee,'attendance:employee:') pages
CROSS JOIN (SELECT '查看详情' label,'query' action,1 num UNION ALL SELECT '新增','add',2
            UNION ALL SELECT '修改与绑定','edit',3 UNION ALL SELECT '删除','remove',4) actions
WHERE NOT EXISTS (SELECT 1 FROM sys_menu m WHERE m.perms=CONCAT(pages.prefix,actions.action));

-- 只向管理员角色补充菜单，其他角色在角色管理中按需授权。
INSERT INTO sys_role_menu(role_id,menu_id)
SELECT 1,m.menu_id FROM sys_menu m WHERE (m.menu_id=@att_root OR m.parent_id=@att_root OR m.parent_id IN (@att_site,@att_employee))
AND EXISTS (SELECT 1 FROM sys_role WHERE role_id=1)
AND NOT EXISTS (SELECT 1 FROM sys_role_menu rm WHERE rm.role_id=1 AND rm.menu_id=m.menu_id);
COMMIT;
