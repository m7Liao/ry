-- Apply only to the original framework seed rows. Keep user-created records.
START TRANSACTION;

DELETE rm FROM sys_role_menu rm
JOIN sys_menu m ON m.menu_id = rm.menu_id
WHERE m.menu_id = 4 AND m.path = 'http://ruoyi.vip';
DELETE FROM sys_menu WHERE menu_id = 4 AND path = 'http://ruoyi.vip';

DELETE nr FROM sys_notice_read nr
JOIN sys_notice n ON n.notice_id = nr.notice_id
WHERE (n.notice_id = 1 AND n.notice_title = '温馨提醒：2018-07-01 若依新版本发布啦')
   OR (n.notice_id = 2 AND n.notice_title = '维护通知：2018-07-01 若依系统凌晨维护')
   OR (n.notice_id = 3 AND n.notice_title = '若依开源框架介绍');
DELETE FROM sys_notice
WHERE (notice_id = 1 AND notice_title = '温馨提醒：2018-07-01 若依新版本发布啦')
   OR (notice_id = 2 AND notice_title = '维护通知：2018-07-01 若依系统凌晨维护')
   OR (notice_id = 3 AND notice_title = '若依开源框架介绍');

DELETE FROM sys_job
WHERE (job_id = 1 AND invoke_target = 'ryTask.ryNoParams')
   OR (job_id = 2 AND invoke_target = 'ryTask.ryParams(\'ry\')')
   OR (job_id = 3 AND invoke_target = 'ryTask.ryMultipleParams(\'ry\', true, 2000L, 316.50D, 100)');

DELETE ur FROM sys_user_role ur JOIN sys_user u ON u.user_id = ur.user_id
WHERE u.user_id = 2 AND u.user_name = 'ry' AND u.remark = '测试员';
DELETE up FROM sys_user_post up JOIN sys_user u ON u.user_id = up.user_id
WHERE u.user_id = 2 AND u.user_name = 'ry' AND u.remark = '测试员';
DELETE FROM sys_user WHERE user_id = 2 AND user_name = 'ry' AND remark = '测试员';

UPDATE sys_user SET dept_id = 100, nick_name = '管理员', email = '', phonenumber = ''
WHERE user_id = 1 AND user_name = 'admin' AND nick_name = '若依' AND dept_id = 103;
UPDATE sys_dept SET dept_name = '默认部门', leader = '', phone = '', email = ''
WHERE dept_id = 100 AND dept_name = '若依科技';

CREATE TEMPORARY TABLE cleanup_seed_depts AS
SELECT dept_id FROM sys_dept
WHERE dept_id BETWEEN 101 AND 109 AND create_by = 'admin'
  AND leader = '若依' AND phone = '15888888888' AND email = 'ry@qq.com';
DELETE rd FROM sys_role_dept rd JOIN cleanup_seed_depts d ON d.dept_id = rd.dept_id
WHERE NOT EXISTS (SELECT 1 FROM sys_user u WHERE u.dept_id = d.dept_id);
DELETE d FROM sys_dept d JOIN cleanup_seed_depts seed ON seed.dept_id = d.dept_id
WHERE NOT EXISTS (SELECT 1 FROM sys_user u WHERE u.dept_id = d.dept_id);
DROP TEMPORARY TABLE cleanup_seed_depts;

DELETE up FROM sys_user_post up JOIN sys_post p ON p.post_id = up.post_id
WHERE up.user_id = 1 AND p.post_id = 1 AND p.post_code = 'ceo' AND p.post_name = '董事长';
DELETE FROM sys_post
WHERE ((post_id = 1 AND post_code = 'ceo' AND post_name = '董事长')
    OR (post_id = 2 AND post_code = 'se' AND post_name = '项目经理')
    OR (post_id = 3 AND post_code = 'hr' AND post_name = '人力资源')
    OR (post_id = 4 AND post_code = 'user' AND post_name = '普通员工'))
  AND NOT EXISTS (SELECT 1 FROM sys_user_post up WHERE up.post_id = sys_post.post_id);

COMMIT;
