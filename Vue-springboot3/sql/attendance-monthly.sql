-- 先安装 attendance-daily.sql；仅新增菜单，可重复执行。
SET NAMES utf8mb4;
START TRANSACTION;
SET @att_root=(SELECT menu_id FROM sys_menu WHERE parent_id=0 AND path='attendance' LIMIT 1);
INSERT INTO sys_menu(menu_name,parent_id,order_num,path,component,route_name,is_frame,is_cache,menu_type,visible,status,perms,icon,create_by,create_time)
SELECT '员工月度汇总',@att_root,6,'monthly','attendance/monthly/index','AttendanceMonthly',1,1,'C','0','0','attendance:monthly:list','date','admin',NOW()
WHERE @att_root IS NOT NULL AND NOT EXISTS(SELECT 1 FROM sys_menu WHERE perms='attendance:monthly:list');
INSERT INTO sys_role_menu(role_id,menu_id)
SELECT 1,m.menu_id FROM sys_menu m WHERE m.perms='attendance:monthly:list' AND NOT EXISTS(SELECT 1 FROM sys_role_menu rm WHERE rm.role_id=1 AND rm.menu_id=m.menu_id);
COMMIT;

