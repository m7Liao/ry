<template>
  <main class="attendance-mobile"><div class="mobile-wrap">
    <header class="mobile-heading"><div><h1>我的月度考勤</h1><p class="mobile-subtitle">本人出勤与工时汇总</p></div><el-button link type="primary" @click="$router.push('/h5/checkin')">返回签到</el-button></header>
    <section class="mobile-card"><el-form label-position="top" @submit.prevent="load" :disabled="loading"><el-form-item label="考勤月份"><input v-model="month" type="month" class="month-input" aria-label="考勤月份" /></el-form-item><el-button type="primary" native-type="submit" :loading="loading">查询 / 刷新</el-button></el-form></section>
    <p v-if="error" class="mobile-error" role="alert">{{ error }}</p>
    <el-empty v-if="!loading && !row && !error" description="该月份暂无已生成结果" />
    <section v-if="row" class="mobile-card"><h2>{{ appliedMonth }} · {{ row.employeeName }}</h2><dl>
      <div><dt>已生成结果</dt><dd>{{ row.generatedDays }}天</dd></div><div><dt>工作日 / 休息日</dt><dd>{{ row.workDays }} / {{ row.restDays }}天</dd></div>
      <div><dt>正常 / 异常</dt><dd>{{ row.normalDays }} / {{ row.abnormalDays }}天</dd></div><div><dt>完整打卡</dt><dd>{{ row.attendedDays }}天</dd></div>
      <div><dt>缺卡</dt><dd>{{ row.missingDays }}天</dd></div><div><dt>待结算</dt><dd>{{ row.pendingDays }}天</dd></div>
      <div><dt>迟到</dt><dd>{{ row.lateDays }}天 / {{ row.lateMinutes }}分钟</dd></div><div><dt>早退</dt><dd>{{ row.earlyDays }}天 / {{ row.earlyMinutes }}分钟</dd></div>
      <div><dt>计划工时</dt><dd>{{ hours(row.plannedWorkMinutes) }}小时</dd></div><div><dt>已确认工时</dt><dd>{{ hours(row.workMinutes) }}小时</dd></div><div><dt>工时待确认</dt><dd>{{ row.unknownWorkDays }}天</dd></div>
    </dl></section>
    <nav class="mobile-actions"><el-button text type="primary" @click="$router.push('/h5/daily')">查看每日结果</el-button></nav>
    <p class="mobile-notice">仅汇总本人已生成结果，本月统计至今天。缺卡和待结算工时不计入已确认工时；未生成日期不代表缺勤。迟到、早退和缺卡可能重叠。计划工时包含已生成待结算日。本页不核算加班或工资。</p>
  </div></main>
</template>
<script setup name="AttendanceMobileMonthly">
import { myMonthly } from '@/api/attendance/monthly'
import { shanghaiMonth, hours } from '@/utils/attendanceMonthly'
import './mobile.css'
const month = ref(shanghaiMonth()), appliedMonth = ref(''), row = ref(null), loading = ref(false), error = ref('')
let version = 0
async function load() {
  if (loading.value) return
  const current = ++version; loading.value = true; error.value = ''; row.value = null
  try {
    if (!/^[1-9]\d{3}-(0[1-9]|1[0-2])$/.test(month.value || '')) throw new Error('请选择有效月份')
    const selected = month.value, r = await myMonthly(selected)
    if (current === version) { row.value = r.data[0] || null; appliedMonth.value = selected }
  } catch (e) { if (current === version) error.value = e.message || '月度汇总加载失败，请重试' }
  finally { if (current === version) loading.value = false }
}
onBeforeUnmount(() => version++)
load()
</script>
<style scoped>.month-input { width:100%; min-height:42px; border:1px solid #dcdfe6; border-radius:4px; padding:0 12px; font:inherit; font-size:16px; background:#fff; color:#243449; box-sizing:border-box; }</style>
