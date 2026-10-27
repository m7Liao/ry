-- 固定班次规则配置。先执行 attendance-base.sql；本脚本不改写签到记录，可重复执行。
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS att_rule (
    rule_id BIGINT NOT NULL AUTO_INCREMENT,
    site_id BIGINT NOT NULL COMMENT '一个场所一套规则',
    rule_name VARCHAR(100) NOT NULL,
    work_days VARCHAR(13) NOT NULL COMMENT '周一至周日为1至7，逗号分隔',
    start_time CHAR(5) NOT NULL COMMENT 'HH:mm',
    end_time CHAR(5) NOT NULL COMMENT 'HH:mm',
    end_next_day CHAR(1) NOT NULL DEFAULT '0' COMMENT '0当天 1次日',
    late_grace_minutes INT NOT NULL DEFAULT 5,
    early_grace_minutes INT NOT NULL DEFAULT 0,
    start_before_minutes INT NOT NULL DEFAULT 60,
    start_after_minutes INT NOT NULL DEFAULT 60,
    end_before_minutes INT NOT NULL DEFAULT 60,
    end_after_minutes INT NOT NULL DEFAULT 120,
    rest_minutes INT NOT NULL DEFAULT 60,
    status CHAR(1) NOT NULL DEFAULT '0' COMMENT '0启用 1停用，首次每日计算需启用',
    version INT NOT NULL DEFAULT 0 COMMENT '防止并发编辑覆盖，不是历史规则版本',
    remark VARCHAR(500) DEFAULT NULL,
    create_by VARCHAR(64) DEFAULT '', create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by VARCHAR(64) DEFAULT '', update_time DATETIME DEFAULT NULL,
    PRIMARY KEY (rule_id),
    UNIQUE KEY uk_att_rule_site (site_id),
    CONSTRAINT fk_att_rule_site FOREIGN KEY (site_id) REFERENCES att_site(site_id),
    CONSTRAINT ck_att_rule_status CHECK (status IN ('0','1') AND end_next_day IN ('0','1')),
    CONSTRAINT ck_att_rule_grace CHECK (late_grace_minutes BETWEEN 0 AND 180 AND early_grace_minutes BETWEEN 0 AND 180),
    CONSTRAINT ck_att_rule_window CHECK (start_before_minutes BETWEEN 0 AND 360 AND start_after_minutes BETWEEN 0 AND 360
        AND end_before_minutes BETWEEN 0 AND 360 AND end_after_minutes BETWEEN 0 AND 360),
    CONSTRAINT ck_att_rule_rest CHECK (rest_minutes BETWEEN 0 AND 720 AND version >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='场所固定班次规则配置';

START TRANSACTION;
SET @att_root = (SELECT menu_id FROM sys_menu WHERE parent_id=0 AND path='attendance' LIMIT 1);
INSERT INTO sys_menu(menu_name,parent_id,order_num,path,component,route_name,is_frame,is_cache,menu_type,visible,status,perms,icon,create_by,create_time)
SELECT '考勤规则配置',@att_root,5,'rule','attendance/rule/index','AttendanceRule',1,1,'C','0','0','attendance:rule:list','time','admin',NOW()
WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='attendance:rule:list');
SET @att_rule = (SELECT menu_id FROM sys_menu WHERE perms='attendance:rule:list' LIMIT 1);

INSERT INTO sys_menu(menu_name,parent_id,order_num,path,is_frame,is_cache,menu_type,visible,status,perms,icon,create_by,create_time)
SELECT a.label,@att_rule,a.num,'#',1,0,'F','0','0',a.perms,'#','admin',NOW()
FROM (
    SELECT '规则详情' label,1 num,'attendance:rule:query' perms
    UNION ALL SELECT '新增规则',2,'attendance:rule:add'
    UNION ALL SELECT '修改规则',3,'attendance:rule:edit'
    UNION ALL SELECT '删除规则',4,'attendance:rule:remove'
) a WHERE NOT EXISTS (SELECT 1 FROM sys_menu m WHERE m.perms=a.perms);

-- 只补充管理员角色权限，不自动向普通角色授权，不插入真实业务规则。
INSERT INTO sys_role_menu(role_id,menu_id)
SELECT 1,m.menu_id FROM sys_menu m
WHERE (m.menu_id=@att_rule OR m.parent_id=@att_rule)
AND EXISTS (SELECT 1 FROM sys_role WHERE role_id=1)
AND NOT EXISTS (SELECT 1 FROM sys_role_menu rm WHERE rm.role_id=1 AND rm.menu_id=m.menu_id);
COMMIT;
