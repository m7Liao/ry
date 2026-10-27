<template>
  <div class="app-container attendance-dashboard">
    <el-form :inline="true" @submit.prevent="load">
      <el-form-item label="统计日期"><el-date-picker v-model="dateRange" type="daterange" value-format="YYYY-MM-DD" :disabled-date="d => d.getTime() > Date.now()" start-placeholder="开始日期" end-placeholder="结束日期" :clearable="false" style="width: 270px" /></el-form-item>
      <el-form-item><el-radio-group v-model="quickDays" @change="selectDays"><el-radio-button :value="7">近7天</el-radio-button><el-radio-button :value="30">近30天</el-radio-button></el-radio-group></el-form-item>
      <el-form-item label="办公场所"><el-select v-model="siteId" clearable filterable placeholder="全部可见场所" style="width: 220px"><el-option v-for="s in availableSites" :key="s.id" :label="s.label" :value="s.id" /></el-select></el-form-item>
      <el-form-item><el-button type="primary" icon="Search" native-type="submit" :loading="loading">查询</el-button><el-button icon="Refresh" @click="reset">重置</el-button></el-form-item>
    </el-form>
    <el-alert class="board-notice" title="仅统计已生成的每日结果，跨日按人次累计。异常按每天每人去重；缺卡和异常类型分布只统计已结算结果，未计算人员不作为缺勤。" type="info" :closable="false" show-icon />
    <el-alert v-if="error" class="board-notice" :title="error" type="error" :closable="false" show-icon />
    <section v-if="view" v-loading="loading">
      <div class="board-caption"><span>{{ view.beginDate }} ～ {{ view.endDate }} · 覆盖 {{ view.summary.employeeCount }} 名员工 · 已生成 {{ view.summary.totalCount }} 条结果 · 休息日 {{ view.summary.restCount }} 人次</span><span>最近计算：{{ view.summary.lastCalculatedTime || '暂无记录' }}</span></div>
      <div class="metric-grid">
        <el-card v-for="m in metrics" :key="m.key" shadow="hover" :body-style="{ padding: '0' }">
          <button class="metric-button" :class="m.tone" type="button" :disabled="!canViewDaily" @click="openDaily(m.filter)"><span class="metric-label">{{ m.label }}</span><strong>{{ view.summary[m.key] }}</strong><span class="metric-unit">人次</span></button>
        </el-card>
      </div>
      <p v-if="!canViewDaily" class="chart-note">当前账号可查看统计；查看明细还需每日结果列表权限。</p>
      <el-row :gutter="16">
        <el-col :xs="24" :lg="15"><el-card shadow="never" class="chart-card"><template #header>每日结果趋势</template><DashboardChart :option="trendChart" label="每日正常、异常、待结算和休息日趋势" @select="selectTrend" /><p class="chart-note">无记录日期补0，表示当日没有已生成的可见结果。</p></el-card></el-col>
        <el-col :xs="24" :lg="9"><el-card shadow="never" class="chart-card"><template #header>已结算异常分布</template><DashboardChart :option="anomalyChart" label="已结算结果中的迟到、早退和缺卡分布" @select="selectAnomaly" /><p class="chart-note">同一人同一天可出现多种异常，各类型不可相加作为异常人次。</p></el-card></el-col>
      </el-row>
      <el-card shadow="never" class="chart-card"><template #header><div class="section-heading"><span>场所对比</span><span class="chart-note">按已生成结果排序，图表展示前10个场所</span></div></template><DashboardChart v-if="topSites.length" :option="siteChart" label="各办公场所的考勤结果对比" @select="selectSite" /><el-empty v-else description="当前条件下暂无场所结果" /></el-card>
      <el-card shadow="never"><template #header>场所统计明细（{{ view.sites.length }} 个场所）</template>
        <el-table :data="pagedSites">
          <el-table-column label="场所名称快照" prop="siteName" min-width="180" show-overflow-tooltip />
          <el-table-column v-for="m in metrics" :key="m.key" :label="m.label + '（人次）'" min-width="135" align="right"><template #default="{ row }"><el-button v-if="canViewDaily" link type="primary" @click="openDaily({ ...m.filter, siteId: row.siteId })">{{ row[m.key] }}</el-button><span v-else>{{ row[m.key] }}</span></template></el-table-column>
          <el-table-column label="休息日（人次）" width="145" align="right"><template #default="{ row }"><el-button v-if="canViewDaily" link type="primary" @click="openDaily({ siteId: row.siteId, resultStatus: 'REST' })">{{ row.restCount }}</el-button><span v-else>{{ row.restCount }}</span></template></el-table-column>
        </el-table>
        <pagination v-show="view.sites.length > 10" :total="view.sites.length" v-model:page="sitePage" v-model:limit="siteLimit" />
      </el-card>
      <p v-if="!view.summary.totalCount" class="chart-note">当前条件下没有已生成结果。可由有权限的管理人员先到“每日考勤结果”进行计算。</p>
    </section>
    <el-skeleton v-else-if="loading" :rows="8" animated />
  </div>
</template>

<script setup name="AttendanceDashboard">
import { getAttendanceDashboard } from '@/api/attendance/dashboard'
import { dailyDashboardRoute } from '@/utils/attendanceDashboard'
import DashboardChart from './DashboardChart.vue'
import { trendOptions, anomalyOptions, siteOptions, statusSeries, anomalySeries } from './chartOptions'
const { proxy } = getCurrentInstance(), router = useRouter()
const dateRange = ref([]), quickDays = ref(7), siteId = ref(), view = ref(null), loading = ref(false), error = ref(''), sitePage = ref(1), siteLimit = ref(10)
const canViewDaily = computed(() => proxy.$auth.hasPermi('attendance:daily:list'))
const metrics = [
  { key: 'settledCount', label: '已结算', tone: 'primary', filter: { resultGroup: 'SETTLED' } },
  { key: 'normalCount', label: '正常', tone: 'success', filter: { resultStatus: 'NORMAL' } },
  { key: 'abnormalCount', label: '异常', tone: 'warning', filter: { resultStatus: 'ABNORMAL' } },
  { key: 'missingCount', label: '缺卡', tone: 'danger', filter: { resultGroup: 'MISSING' } },
  { key: 'pendingCount', label: '待结算', tone: 'muted', filter: { resultStatus: 'PENDING' } }
]
let requestVersion = 0, activated = false
const availableSites = computed(() => {
  const options = view.value?.siteOptions || []
  return siteId.value && !options.some(s => s.id === siteId.value) ? [...options, { id: siteId.value, label: `场所 ${siteId.value}（当前期间无可见结果）` }] : options
})
const topSites = computed(() => view.value?.sites.slice(0, 10) || [])
const pagedSites = computed(() => view.value?.sites.slice((sitePage.value - 1) * siteLimit.value, sitePage.value * siteLimit.value) || [])
const trendChart = computed(() => trendOptions(view.value?.trend || []))
const anomalyChart = computed(() => anomalyOptions(view.value?.summary || {}))
const siteChart = computed(() => siteOptions(topSites.value))
function recentDays(days) {
  const parts = Object.fromEntries(new Intl.DateTimeFormat('en', { timeZone: 'Asia/Shanghai', year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(new Date()).map(p => [p.type, p.value]))
  const end = `${parts.year}-${parts.month}-${parts.day}`, start = new Date(end + 'T00:00:00Z')
  start.setUTCDate(start.getUTCDate() - days + 1)
  return [start.toISOString().slice(0, 10), end]
}
async function load() {
  if (!dateRange.value?.[0] || !dateRange.value?.[1]) return proxy.$modal.msgWarning('请选择完整的统计日期')
  const version = ++requestVersion, requestedSite = siteId.value
  loading.value = true; error.value = ''
  try {
    const r = await getAttendanceDashboard({ beginDate: dateRange.value[0], endDate: dateRange.value[1], siteId: requestedSite })
    if (version !== requestVersion) return
    view.value = r.data; sitePage.value = 1
  } catch (e) { if (version === requestVersion) error.value = (e.message || '统计加载失败，请重试') + (view.value ? '；下方保留上次成功查询的结果。' : '') }
  finally { if (version === requestVersion) loading.value = false }
}
function selectDays(days) { dateRange.value = recentDays(days); load() }
function reset() { siteId.value = undefined; quickDays.value = 7; selectDays(7) }
function openDaily(extra = {}) {
  if (!canViewDaily.value || !view.value) return
  router.push(dailyDashboardRoute({ beginDate: view.value.beginDate, endDate: view.value.endDate, siteId: view.value.siteId, ...extra }))
}
function selectTrend(event) {
  const day = view.value?.trend[event.dataIndex], series = statusSeries.find(s => s.name === event.seriesName)
  if (day && series) openDaily({ beginDate: day.attendanceDate, endDate: day.attendanceDate, resultStatus: series.status })
}
function selectAnomaly(event) { const type = anomalySeries[event.dataIndex]?.type; if (type) openDaily({ resultGroup: 'SETTLED', abnormalType: type }) }
function selectSite(event) { const site = topSites.value[event.dataIndex], series = statusSeries.find(s => s.name === event.seriesName); if (site && series) openDaily({ siteId: site.siteId, resultStatus: series.status }) }
onBeforeUnmount(() => { requestVersion++ })
onDeactivated(() => { requestVersion++; loading.value = false; view.value = null })
onActivated(() => { if (activated) load(); activated = true })
watch(dateRange, range => { quickDays.value = [7, 30].find(days => JSON.stringify(range) === JSON.stringify(recentDays(days))) })
dateRange.value = recentDays(7); load()
</script>

<style scoped>
.board-notice { margin-bottom: 18px; }
.board-caption, .section-heading { display: flex; justify-content: space-between; flex-wrap: wrap; gap: 10px; }
.board-caption { color: var(--el-text-color-secondary); font-size: 13px; line-height: 1.7; margin-bottom: 16px; }
.metric-grid { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 16px; margin-bottom: 20px; }
.metric-button { background: var(--el-bg-color); border: 0; width: 100%; text-align: left; padding: 20px; color: var(--el-color-primary); cursor: pointer; }
.metric-button:disabled { cursor: default; }
.metric-button:focus-visible { outline: 2px solid var(--el-color-primary); outline-offset: -3px; }
.metric-label { display: block; color: var(--el-text-color-regular); font-size: 14px; margin-bottom: 14px; }
.metric-button strong { font-size: 30px; font-weight: 600; }
.metric-unit { font-size: 12px; margin-left: 8px; color: var(--el-text-color-secondary); }
.success { color: var(--el-color-success); } .warning { color: var(--el-color-warning); } .danger { color: var(--el-color-danger); } .muted { color: var(--el-text-color-secondary); }
.chart-card { margin-bottom: 16px; }
.chart-note { color: var(--el-text-color-secondary); font-size: 12px; line-height: 1.8; margin: 0; }
@media (max-width: 1250px) { .metric-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
@media (max-width: 700px) { .metric-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; } .metric-button { padding: 16px; } }
</style>
