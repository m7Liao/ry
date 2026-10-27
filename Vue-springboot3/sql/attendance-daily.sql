-- 先执行 attendance-base.sql、attendance-checkin.sql、attendance-rule.sql。本增量可重复执行，不清空原始记录。
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS att_daily_result (
    result_id BIGINT NOT NULL AUTO_INCREMENT,
    attendance_date DATE NOT NULL,
    employee_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    dept_id BIGINT NOT NULL,
    site_id BIGINT NOT NULL,
    employee_no VARCHAR(32) NOT NULL,
    employee_name VARCHAR(50) NOT NULL,
    user_name VARCHAR(30) NOT NULL,
    dept_name VARCHAR(100) NOT NULL,
    site_name VARCHAR(100) NOT NULL,
    rule_id BIGINT NOT NULL,
    rule_name VARCHAR(100) NOT NULL,
    rule_version INT NOT NULL,
    rule_snapshot LONGTEXT NOT NULL,
    scheduled_start DATETIME NOT NULL,
    scheduled_end DATETIME NOT NULL,
    start_window_start DATETIME NOT NULL,
    start_window_end DATETIME NOT NULL,
    end_window_start DATETIME NOT NULL,
    end_window_end DATETIME NOT NULL,
    in_record_id BIGINT DEFAULT NULL,
    out_record_id BIGINT DEFAULT NULL,
    in_time DATETIME(3) DEFAULT NULL,
    out_time DATETIME(3) DEFAULT NULL,
    work_day TINYINT NOT NULL,
    result_status VARCHAR(12) NOT NULL,
    missing_in TINYINT NOT NULL,
    missing_out TINYINT NOT NULL,
    late_minutes INT NOT NULL,
    early_minutes INT NOT NULL,
    planned_work_minutes INT NOT NULL,
    work_minutes INT DEFAULT NULL,
    calculation_count INT NOT NULL DEFAULT 1,
    calculated_by VARCHAR(64) NOT NULL,
    calculated_time DATETIME(3) NOT NULL,
    PRIMARY KEY (result_id),
    UNIQUE KEY uk_att_daily_employee_date (employee_id,attendance_date),
    KEY idx_att_daily_dept_date (dept_id,attendance_date),
    KEY idx_att_daily_site_date (site_id,attendance_date),
    KEY idx_att_daily_user_date (user_id,attendance_date),
    KEY idx_att_daily_rule (rule_id),
    CONSTRAINT fk_att_daily_employee FOREIGN KEY (employee_id) REFERENCES att_employee(employee_id),
    CONSTRAINT fk_att_daily_user FOREIGN KEY (user_id) REFERENCES sys_user(user_id),
    CONSTRAINT fk_att_daily_site FOREIGN KEY (site_id) REFERENCES att_site(site_id),
    CONSTRAINT fk_att_daily_rule FOREIGN KEY (rule_id) REFERENCES att_rule(rule_id),
    CONSTRAINT fk_att_daily_in FOREIGN KEY (in_record_id) REFERENCES att_checkin_record(record_id),
    CONSTRAINT fk_att_daily_out FOREIGN KEY (out_record_id) REFERENCES att_checkin_record(record_id),
    CONSTRAINT ck_att_daily_status CHECK (result_status IN ('PENDING','REST','NORMAL','ABNORMAL')),
    CONSTRAINT ck_att_daily_flags CHECK (work_day IN (0,1) AND missing_in IN (0,1) AND missing_out IN (0,1)),
    CONSTRAINT ck_att_daily_minutes CHECK (late_minutes >= 0 AND early_minutes >= 0 AND planned_work_minutes >= 0
        AND (work_minutes IS NULL OR work_minutes >= 0) AND calculation_count >= 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='每日考勤结果及首次计算规则快照';

START TRANSACTION;
SET @att_root = (SELECT menu_id FROM sys_menu WHERE parent_id=0 AND path='attendance' LIMIT 1);
INSERT INTO sys_menu(menu_name,parent_id,order_num,path,component,route_name,is_frame,is_cache,menu_type,visible,status,perms,icon,create_by,create_time)
SELECT '每日考勤结果',@att_root,6,'daily','attendance/daily/index','AttendanceDaily',1,1,'C','0','0','attendance:daily:list','date','admin',NOW()
WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='attendance:daily:list');
SET @att_daily = (SELECT menu_id FROM sys_menu WHERE perms='attendance:daily:list' LIMIT 1);
INSERT INTO sys_menu(menu_name,parent_id,order_num,path,is_frame,is_cache,menu_type,visible,status,perms,icon,create_by,create_time)
SELECT a.label,@att_daily,a.num,'#',1,0,'F','0','0',a.perms,'#','admin',NOW()
FROM (
    SELECT '结果详情' label,1 num,'attendance:daily:query' perms
    UNION ALL SELECT '手动计算',2,'attendance:daily:calculate'
    UNION ALL SELECT '按快照重算',3,'attendance:daily:recalculate'
) a WHERE NOT EXISTS (SELECT 1 FROM sys_menu m WHERE m.perms=a.perms);
INSERT INTO sys_role_menu(role_id,menu_id)
SELECT 1,m.menu_id FROM sys_menu m
WHERE (m.menu_id=@att_daily OR m.parent_id=@att_daily)
AND EXISTS (SELECT 1 FROM sys_role WHERE role_id=1)
AND NOT EXISTS (SELECT 1 FROM sys_role_menu rm WHERE rm.role_id=1 AND rm.menu_id=m.menu_id);
COMMIT;
