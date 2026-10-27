<template>
  <main class="attendance-mobile"><div class="mobile-wrap">
    <header class="mobile-heading"><div><h1>我的每日考勤</h1><p class="mobile-subtitle">查看本人已生成的考勤结果与工时</p></div><el-button link type="primary" @click="$router.push('/h5/checkin')">返回签到</el-button></header>
    <section class="mobile-card">
      <el-form label-position="top" @submit.prevent="refresh" :disabled="loading">
        <el-form-item label="考勤月份"><input v-model="month" type="month" class="month-input" aria-label="考勤月份" :disabled="loading" /></el-form-item>
        <el-form-item label="结果状态"><el-select v-model="status" clearable placeholder="全部状态" style="width: 100%"><el-option v-for="(item, key) in states" :key="key" :label="item.label" :value="key" /></el-select></el-form-item>
        <el-button type="primary" native-type="submit" :loading="loading">查询 / 刷新</el-button>
      </el-form>
    </section>
    <p v-if="error" class="mobile-error" role="alert">{{ error }}</p>
    <el-empty v-if="!loading && !rows.length && !error" description="该月份暂无已生成结果" />
    <article v-for="r in rows" :key="r.resultId" class="mobile-card">
      <div class="daily-heading"><h2>{{ r.attendanceDate }}</h2><el-tag :type="states[r.resultStatus]?.type">{{ states[r.resultStatus]?.label }}</el-tag></div>
      <dl><div><dt>办公场所</dt><dd>{{ r.siteName }}</dd></div><div><dt>计划上班</dt><dd>{{ r.scheduledStart }}</dd></div><div><dt>计划下班</dt><dd>{{ r.scheduledEnd }}</dd></div><div><dt>上班打卡</dt><dd>{{ r.inTime || '未匹配' }}</dd></div><div><dt>下班打卡</dt><dd>{{ r.outTime || '未匹配' }}</dd></div><div><dt>计划工时</dt><dd>{{ duration(r.plannedWorkMinutes) }}</dd></div><div><dt>计算工时</dt><dd>{{ r.resultStatus === 'PENDING' ? '待结算' : r.workMinutes == null ? '待确认' : duration(r.workMinutes) }}</dd></div><div><dt>更新时间</dt><dd>{{ r.calculatedTime }}</dd></div></dl>
      <p v-if="anomalies(r).length" class="mobile-error">{{ anomalies(r).join('、') }}{{ r.resultStatus === 'PENDING' ? '（尚未最终结算）' : '' }}</p>
    </article>
    <div class="mobile-actions"><el-button v-if="rows.length < total" type="primary" plain :loading="loading" @click="more">加载更多</el-button><el-button text type="primary" @click="$router.push('/h5/records')">原始签到记录</el-button><el-button text type="primary" @click="$router.push('/h5/monthly')">月度汇总</el-button></div>
    <p v-if="rows.length" class="mobile-notice" style="text-align: center">已显示 {{ rows.length }} / {{ total }} 条</p>
    <p class="mobile-notice">跨天班次归属上班当天。没有结果不等于缺勤；窗口未结束时需等待结算。对结果有疑问，请联系管理员核对。</p>
  </div></main>
</template>

<script setup name="AttendanceMobileDaily">
import { myDailyResults } from '@/api/attendance/checkin'
import './mobile.css'
const parts = Object.fromEntries(new Intl.DateTimeFormat('en', { timeZone: 'Asia/Shanghai', year: 'numeric', month: '2-digit' }).formatToParts(new Date()).map(p => [p.type, p.value]))
const month = ref(`${parts.year}-${parts.month}`), status = ref(''), rows = ref([]), total = ref(0), loading = ref(false), error = ref('')
const states = { NORMAL: { label: '正常', type: 'success' }, ABNORMAL: { label: '异常', type: 'warning' }, PENDING: { label: '待结算', type: 'info' }, REST: { label: '休息日', type: 'info' } }
let page = 0, applied, version = 0
const duration = minutes => minutes == null ? '待确认' : `${Math.floor(minutes / 60)}小时${minutes % 60 ? minutes % 60 + '分钟' : ''}`
function anomalies(row) { const items = []; if (row.lateMinutes > 0) items.push(`迟到${row.lateMinutes}分钟`); if (row.earlyMinutes > 0) items.push(`早退${row.earlyMinutes}分钟`); if (row.missingIn) items.push('上班缺卡'); if (row.missingOut) items.push('下班缺卡'); return items }
function filters() {
  if (!/^[1-9]\d{3}-(0[1-9]|1[0-2])$/.test(month.value || '')) throw new Error('请选择有效的考勤月份')
  const [year, m] = month.value.split('-').map(Number)
  return { beginDate: month.value + '-01', endDate: new Date(Date.UTC(year, m, 0)).toISOString().slice(0, 10), resultStatus: status.value }
}
async function load(append) {
  if (loading.value) return
  const current = ++version, nextPage = append ? page + 1 : 1
  loading.value = true; error.value = ''
  try {
    const query = append ? applied : filters()
    const r = await myDailyResults({ ...query, pageNum: nextPage, pageSize: 10 })
    if (current !== version) return
    const ids = new Set(rows.value.map(v => v.resultId))
    rows.value = append ? [...rows.value, ...r.rows.filter(v => !ids.has(v.resultId))] : r.rows
    page = nextPage; applied = query; total.value = r.total
  } catch (e) { if (current === version) error.value = e.message || '考勤结果加载失败，请重试' }
  finally { if (current === version) loading.value = false }
}
function refresh() { load(false) }
function more() { load(true) }
onBeforeUnmount(() => version++)
refresh()
</script>

<style scoped>.month-input { width: 100%; min-height: 42px; border: 1px solid #dcdfe6; border-radius: 4px; padding: 0 12px; background: #fff; font: inherit; font-size: 16px; color: #243449; box-sizing: border-box; } .daily-heading { display: flex; justify-content: space-between; gap: 12px; align-items: center; margin-bottom: 10px; } .daily-heading h2 { margin-bottom: 0; }</style>
