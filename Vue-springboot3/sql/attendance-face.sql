-- 先安装场所员工与扫码签到。只增加人脸档案/成功核验记录，不存原始照片。
SET NAMES utf8mb4;
CREATE TABLE IF NOT EXISTS att_employee_face (
    employee_id BIGINT NOT NULL PRIMARY KEY,
    encrypted_feature VARBINARY(8192) NOT NULL,
    model VARCHAR(32) NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(64) NOT NULL,
    updated_time DATETIME NOT NULL,
    CONSTRAINT fk_face_employee FOREIGN KEY(employee_id) REFERENCES att_employee(employee_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='加密员工人脸特征';
CREATE TABLE IF NOT EXISTS att_face_verification (
    record_id BIGINT NOT NULL PRIMARY KEY,
    score DOUBLE NOT NULL,
    threshold DOUBLE NOT NULL,
    profile_version BIGINT NOT NULL,
    model VARCHAR(32) NOT NULL,
    verified_time DATETIME NOT NULL,
    CONSTRAINT fk_face_verification_record FOREIGN KEY(record_id) REFERENCES att_checkin_record(record_id),
    CONSTRAINT ck_face_score CHECK(score>=0 AND score<=1 AND threshold>0 AND threshold<1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='成功签到的人脸核验摘要';
SET @face_method_exists=(SELECT count(*) FROM information_schema.table_constraints WHERE constraint_schema=DATABASE() AND table_name='att_checkin_record' AND constraint_name='ck_checkin_record_method');
SET @face_method_sql=IF(@face_method_exists>0,
  'ALTER TABLE att_checkin_record DROP CHECK ck_checkin_record_method, ADD CONSTRAINT ck_checkin_record_method CHECK(checkin_method IN (''QR'',''QR_FACE''))',
  'ALTER TABLE att_checkin_record ADD CONSTRAINT ck_checkin_record_method CHECK(checkin_method IN (''QR'',''QR_FACE''))');
PREPARE face_method_stmt FROM @face_method_sql; EXECUTE face_method_stmt; DEALLOCATE PREPARE face_method_stmt;
START TRANSACTION;
SET @face_parent=(SELECT menu_id FROM sys_menu WHERE perms='attendance:employee:list' LIMIT 1);
INSERT INTO sys_menu(menu_name,parent_id,order_num,path,is_frame,is_cache,menu_type,visible,status,perms,icon,create_by,create_time)
SELECT a.label,@face_parent,a.num,'#',1,0,'F','0','0',a.perms,'#','admin',NOW() FROM (
    SELECT '人脸档案查询' label,5 num,'attendance:face:query' perms
    UNION ALL SELECT '人脸录入',6,'attendance:face:enroll'
    UNION ALL SELECT '人脸撤销',7,'attendance:face:remove'
) a WHERE @face_parent IS NOT NULL AND NOT EXISTS(SELECT 1 FROM sys_menu m WHERE m.perms=a.perms);
INSERT INTO sys_role_menu(role_id,menu_id)
SELECT 1,m.menu_id FROM sys_menu m WHERE m.perms LIKE 'attendance:face:%'
AND NOT EXISTS(SELECT 1 FROM sys_role_menu rm WHERE rm.role_id=1 AND rm.menu_id=m.menu_id);
COMMIT;
