-- 先安装每日考勤模块。本增量只创建暂停的真实任务模板，不新增业务表、不启用全部场所。
SET NAMES utf8mb4;
INSERT INTO sys_job(job_name,job_group,invoke_target,cron_expression,misfire_policy,concurrent,status,create_by,create_time,remark)
SELECT '考勤自动日结（先配置场所范围）','DEFAULT','attendanceDailyTask.settle('''')','0 0/10 * * * ?','3','1','1','admin',NOW(),
       '先把空参数改为明确的场所ID，例如 attendanceDailyTask.settle(''1,2'')，保存后启用。最近3天新建，历史待结算按原快照处理。'
WHERE NOT EXISTS (SELECT 1 FROM sys_job WHERE invoke_target LIKE 'attendanceDailyTask.settle(%');
