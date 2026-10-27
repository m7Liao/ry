-- 先安装 attendance-daily.sql。本增量仅补充菜单与管理员权限，可重复执行，不新增表。
SET NAMES utf8mb4;
START TRANSACTION;
SET @att_root = (SELECT menu_id FROM sys_menu WHERE parent_id=0 AND path='attendance' LIMIT 1);
INSERT INTO sys_menu(menu_name,parent_id,order_num,path,component,route_name,is_frame,is_cache,menu_type,visible,status,perms,icon,create_by,create_time)
SELECT '考勤看板',@att_root,0,'dashboard','attendance/dashboard/index','AttendanceDashboard',1,1,'C','0','0','attendance:dashboard:view','chart','admin',NOW()
WHERE NOT EXISTS (SELECT 1 FROM sys_menu WHERE perms='attendance:dashboard:view');
SET @att_dashboard = (SELECT menu_id FROM sys_menu WHERE perms='attendance:dashboard:view' LIMIT 1);
INSERT INTO sys_role_menu(role_id,menu_id)
SELECT 1,@att_dashboard WHERE EXISTS (SELECT 1 FROM sys_role WHERE role_id=1)
AND NOT EXISTS (SELECT 1 FROM sys_role_menu WHERE role_id=1 AND menu_id=@att_dashboard);
COMMIT;
