-- 先执行 attendance-base.sql，再执行本增量脚本。可重复执行，不清空业务数据。
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS att_checkin_session (
    session_id BIGINT NOT NULL AUTO_INCREMENT COMMENT '签到场次ID',
    site_id BIGINT NOT NULL,
    dept_id BIGINT NOT NULL COMMENT '创建时管理部门快照，用于数据范围',
    title VARCHAR(100) NOT NULL,
    start_time DATETIME(3) NOT NULL,
    end_time DATETIME(3) NOT NULL,
    status CHAR(1) NOT NULL DEFAULT '0' COMMENT '0开放 1手动关闭',
    create_by VARCHAR(64) DEFAULT '', create_time DATETIME(3) NOT NULL,
    update_by VARCHAR(64) DEFAULT '', update_time DATETIME(3) DEFAULT NULL,
    PRIMARY KEY (session_id), KEY idx_checkin_session_dept (dept_id,session_id), KEY idx_checkin_session_site (site_id),
    CONSTRAINT fk_checkin_session_site FOREIGN KEY (site_id) REFERENCES att_site(site_id),
    CONSTRAINT ck_checkin_session_time CHECK (end_time > start_time),
    CONSTRAINT ck_checkin_session_status CHECK (status IN ('0','1'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='签到场次';

CREATE TABLE IF NOT EXISTS att_checkin_record (
    record_id BIGINT NOT NULL AUTO_INCREMENT,
    session_id BIGINT NOT NULL,
    employee_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    dept_id BIGINT NOT NULL COMMENT '签到时员工部门ID快照',
    site_id BIGINT NOT NULL,
    employee_no VARCHAR(32) NOT NULL,
    employee_name VARCHAR(50) NOT NULL,
    user_name VARCHAR(30) NOT NULL,
    dept_name VARCHAR(100) NOT NULL,
    site_name VARCHAR(100) NOT NULL,
    session_title VARCHAR(100) NOT NULL,
    checkin_time DATETIME(3) NOT NULL COMMENT '服务器时间',
    checkin_method VARCHAR(10) NOT NULL DEFAULT 'QR',
    PRIMARY KEY (record_id),
    UNIQUE KEY uk_checkin_session_employee (session_id,employee_id),
    KEY idx_checkin_record_dept_time (dept_id,checkin_time),
    KEY idx_checkin_record_user_time (user_id,checkin_time),
    KEY idx_checkin_record_site_time (site_id,checkin_time),
    CONSTRAINT fk_checkin_record_session FOREIGN KEY (session_id) REFERENCES att_checkin_session(session_id),
    CONSTRAINT fk_checkin_record_employee FOREIGN KEY (employee_id) REFERENCES att_employee(employee_id),
    CONSTRAINT fk_checkin_record_user FOREIGN KEY (user_id) REFERENCES sys_user(user_id),
    CONSTRAINT fk_checkin_record_site FOREIGN KEY (site_id) REFERENCES att_site(site_id),
    CONSTRAINT ck_checkin_record_method CHECK (checkin_method='QR')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='原始扫码签到记录';

START TRANSACTION;
SET @att_root = (SELECT menu_id FROM sys_menu WHERE parent_id=0 AND path='attendance' LIMIT 1);
INSERT INTO sys_menu(menu_name,parent_id,order_num,path,component,route_name,is_frame,is_cache,menu_type,visible,status,perms,icon,create_by,create_time)
SELECT '签到场次与二维码',@att_root,3,'session','attendance/session/index','AttendanceSession',1,1,'C','0','0','attendance:session:list','validCode','admin',NOW()
WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='attendance:session:list');
INSERT INTO sys_menu(menu_name,parent_id,order_num,path,component,route_name,is_frame,is_cache,menu_type,visible,status,perms,icon,create_by,create_time)
SELECT '签到记录',@att_root,4,'record','attendance/record/index','AttendanceRecord',1,1,'C','0','0','attendance:record:list','list','admin',NOW()
WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='attendance:record:list');
SET @att_session = (SELECT menu_id FROM sys_menu WHERE perms='attendance:session:list' LIMIT 1);
SET @att_record = (SELECT menu_id FROM sys_menu WHERE perms='attendance:record:list' LIMIT 1);

INSERT INTO sys_menu(menu_name,parent_id,order_num,path,is_frame,is_cache,menu_type,visible,status,perms,icon,create_by,create_time)
SELECT a.label,a.parent_id,a.num,'#',1,0,'F','0','0',a.perms,'#','admin',NOW()
FROM (
    SELECT '场次详情' label,@att_session parent_id,1 num,'attendance:session:query' perms
    UNION ALL SELECT '创建场次',@att_session,2,'attendance:session:add'
    UNION ALL SELECT '关闭场次',@att_session,3,'attendance:session:edit'
    UNION ALL SELECT '展示动态二维码',@att_session,4,'attendance:session:qrcode'
    UNION ALL SELECT '签到记录详情',@att_record,1,'attendance:record:query'
    UNION ALL SELECT '移动扫码签到',@att_root,5,'attendance:checkin:submit'
) a WHERE NOT EXISTS (SELECT 1 FROM sys_menu m WHERE m.perms=a.perms);

-- 新功能仅授予管理员；员工角色按需勾选“移动扫码签到”。
INSERT INTO sys_role_menu(role_id,menu_id)
SELECT 1,m.menu_id FROM sys_menu m
WHERE (m.menu_id IN (@att_session,@att_record) OR m.parent_id IN (@att_session,@att_record) OR m.perms='attendance:checkin:submit')
AND EXISTS (SELECT 1 FROM sys_role WHERE role_id=1)
AND NOT EXISTS (SELECT 1 FROM sys_role_menu rm WHERE rm.role_id=1 AND rm.menu_id=m.menu_id);
COMMIT;
