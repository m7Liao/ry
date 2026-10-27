<template>
  <div class="app-container">
    <el-alert class="daily-notice" title="结果由手动计算生成。打卡窗口尚未结束时为“待结算”，结束后需按快照重算。缺卡工时显示“待确认”，休息日不核算加班。" type="info" :closable="false" show-icon />
    <el-form ref="queryRef" :model="query" :inline="true" v-show="showSearch">
      <el-form-item label="工号" prop="employeeNo"><el-input v-model="query.employeeNo" clearable style="width: 150px" @keyup.enter="search" /></el-form-item>
      <el-form-item label="姓名" prop="employeeName"><el-input v-model="query.employeeName" clearable style="width: 150px" @keyup.enter="search" /></el-form-item>
      <el-form-item label="办公场所" prop="siteId"><el-select v-model="query.siteId" filterable remote :remote-method="loadSites" clearable style="width: 220px"><el-option v-for="s in filterSites" :key="s.id" :label="s.label" :value="s.id" /></el-select></el-form-item>
      <el-form-item label="考勤日期"><el-date-picker v-model="dateRange" type="daterange" value-format="YYYY-MM-DD" start-placeholder="开始日期" end-placeholder="结束日期" style="width: 260px" /></el-form-item>
      <el-form-item label="结果状态" prop="resultStatus"><el-select v-model="query.resultStatus" clearable style="width: 130px"><el-option v-for="(s, code) in states" :key="code" :label="s.label" :value="code" /></el-select></el-form-item>
      <el-form-item label="异常类型" prop="abnormalType"><el-select v-model="query.abnormalType" clearable style="width: 145px"><el-option label="迟到" value="LATE" /><el-option label="早退" value="EARLY" /><el-option label="上班缺卡" value="MISSING_IN" /><el-option label="下班缺卡" value="MISSING_OUT" /></el-select></el-form-item>
      <el-form-item label="统计范围" prop="resultGroup"><el-select v-model="query.resultGroup" clearable style="width: 160px"><el-option label="已结算" value="SETTLED" /><el-option label="已结算缺卡" value="MISSING" /></el-select></el-form-item>
      <el-form-item><el-button type="primary" icon="Search" @click="search">搜索</el-button><el-button icon="Refresh" @click="resetQuery">重置</el-button></el-form-item>
    </el-form>
    <el-row class="mb8" :gutter="10">
      <el-col :span="1.5"><el-button type="primary" plain icon="Plus" v-hasPermi="['attendance:daily:calculate']" @click="openCalculate">手动计算</el-button></el-col>
      <el-col :span="1.5"><el-button type="warning" plain icon="Refresh" v-hasPermi="['attendance:daily:recalculate']" :disabled="!selected.length || recalculating" :loading="recalculating" @click="recalculate(selected)">按快照重算</el-button></el-col>
      <right-toolbar v-model:showSearch="showSearch" @queryTable="load" />
    </el-row>
    <el-table v-loading="loading" :data="rows" row-key="resultId" @selection-change="selection => selected = selection.map(r => r.resultId)">
      <el-table-column type="selection" width="45" />
      <el-table-column label="考勤日期" prop="attendanceDate" width="115" />
      <el-table-column label="工号" prop="employeeNo" min-width="120" show-overflow-tooltip />
      <el-table-column label="姓名" prop="employeeName" min-width="100" />
      <el-table-column label="部门" prop="deptName" min-width="130" show-overflow-tooltip />
      <el-table-column label="办公场所" prop="siteName" min-width="140" show-overflow-tooltip />
      <el-table-column label="上班打卡" prop="inTime" width="175"><template #default="{ row }">{{ row.inTime || '未匹配' }}</template></el-table-column>
      <el-table-column label="下班打卡" prop="outTime" width="175"><template #default="{ row }">{{ row.outTime || '未匹配' }}</template></el-table-column>
      <el-table-column label="结果" width="100"><template #default="{ row }"><el-tag :type="states[row.resultStatus]?.type">{{ states[row.resultStatus]?.label }}</el-tag></template></el-table-column>
      <el-table-column label="异常明细" min-width="220"><template #default="{ row }"><el-tag v-for="label in anomalies(row)" :key="label" type="warning" class="anomaly">{{ label }}</el-tag><span v-if="!anomalies(row).length">—</span></template></el-table-column>
      <el-table-column label="工时" width="125"><template #default="{ row }">{{ workLabel(row) }}</template></el-table-column>
      <el-table-column label="最近计算" prop="calculatedTime" width="175" />
      <el-table-column label="操作" width="170" fixed="right"><template #default="{ row }">
        <el-button link type="primary" v-hasPermi="['attendance:daily:query']" @click="detail(row)">详情</el-button>
        <el-button link type="warning" v-hasPermi="['attendance:daily:recalculate']" :disabled="recalculating" @click="recalculate([row.resultId])">按快照重算</el-button>
      </template></el-table-column>
    </el-table>
    <pagination v-show="total > 0" :total="total" v-model:page="query.pageNum" v-model:limit="query.pageSize" @pagination="load" />

    <el-dialog v-model="calculateOpen" title="手动计算每日考勤" width="min(580px, 95vw)" append-to-body :close-on-click-modal="false">
      <el-alert title="首次计算使用该场所当前启用规则及当前绑定员工，已有日期结果会跳过。请核对历史日期的人员和规则是否适用。" type="warning" :closable="false" show-icon class="daily-notice" />
      <el-form ref="calculateRef" :model="form" :rules="rules" label-width="100px" :disabled="calculating">
        <el-form-item label="办公场所" prop="siteId"><el-select v-model="form.siteId" filterable remote :remote-method="loadSites" style="width: 100%"><el-option v-for="s in sites" :key="s.id" :label="s.label" :value="s.id" /></el-select></el-form-item>
        <el-form-item label="考勤日期" prop="attendanceDate"><el-date-picker v-model="form.attendanceDate" type="date" value-format="YYYY-MM-DD" :disabled-date="d => d.getTime() > Date.now()" placeholder="班次开始日期" style="width: 100%" /></el-form-item>
      </el-form>
      <p class="form-note">一次处理一个场所、一天和当前账号数据范围内的员工，最多1000人。跨天班次按上班当天归属；当天结果可能仍为待结算。</p>
      <template #footer><el-button @click="calculateOpen = false">取消</el-button><el-button type="primary" :loading="calculating" @click="calculate">开始计算</el-button></template>
    </el-dialog>

    <el-dialog v-model="detailOpen" title="每日考勤详情与规则快照" width="min(900px, 96vw)" append-to-body>
      <el-descriptions :column="2" border>
        <el-descriptions-item label="考勤日期">{{ record.attendanceDate }}</el-descriptions-item><el-descriptions-item label="结果状态">{{ states[record.resultStatus]?.label }}</el-descriptions-item>
        <el-descriptions-item label="员工">{{ record.employeeName }} / {{ record.employeeNo }}</el-descriptions-item><el-descriptions-item label="账号">{{ record.userName }}</el-descriptions-item>
        <el-descriptions-item label="部门快照">{{ record.deptName }}</el-descriptions-item><el-descriptions-item label="场所快照">{{ record.siteName }}</el-descriptions-item>
        <el-descriptions-item label="计划上班">{{ record.scheduledStart }}</el-descriptions-item><el-descriptions-item label="计划下班">{{ record.scheduledEnd }}</el-descriptions-item>
        <el-descriptions-item label="上班窗口" :span="2">{{ record.startWindowStart }} ～ {{ record.startWindowEnd }}</el-descriptions-item>
        <el-descriptions-item label="下班窗口" :span="2">{{ record.endWindowStart }} ～ {{ record.endWindowEnd }}</el-descriptions-item>
        <el-descriptions-item label="上班记录">{{ record.inTime || '未匹配' }}<span v-if="record.inRecordId">（编号 {{ record.inRecordId }}）</span></el-descriptions-item>
        <el-descriptions-item label="下班记录">{{ record.outTime || '未匹配' }}<span v-if="record.outRecordId">（编号 {{ record.outRecordId }}）</span></el-descriptions-item>
        <el-descriptions-item label="异常明细" :span="2">{{ anomalies(record).join('、') || '无' }}</el-descriptions-item>
        <el-descriptions-item label="计划工时">{{ duration(record.plannedWorkMinutes) }}</el-descriptions-item><el-descriptions-item label="本次工时">{{ workLabel(record) }}</el-descriptions-item>
        <el-descriptions-item label="计算次数">{{ record.calculationCount }}</el-descriptions-item><el-descriptions-item label="计算人">{{ record.calculatedBy }}</el-descriptions-item>
        <el-descriptions-item label="最近计算时间" :span="2">{{ record.calculatedTime }}</el-descriptions-item>
      </el-descriptions>
      <template v-if="record.ruleConfig">
        <el-divider content-position="left">首次计算保存的规则</el-divider>
        <el-descriptions :column="2" border>
          <el-descriptions-item label="规则">{{ record.ruleName }}</el-descriptions-item><el-descriptions-item label="规则版本">{{ record.ruleVersion }}（{{ record.ruleConfig.algorithm }}）</el-descriptions-item>
          <el-descriptions-item label="工作日" :span="2">{{ weekLabel(record.ruleConfig.workDays) }}</el-descriptions-item>
          <el-descriptions-item label="上下班">{{ record.ruleConfig.startTime }} ～ {{ record.ruleConfig.endNextDay === '1' ? '次日 ' : '' }}{{ record.ruleConfig.endTime }}</el-descriptions-item><el-descriptions-item label="休息">{{ record.ruleConfig.restMinutes }}分钟</el-descriptions-item>
          <el-descriptions-item label="迟到宽限">{{ record.ruleConfig.lateGraceMinutes }}分钟</el-descriptions-item><el-descriptions-item label="早退宽限">{{ record.ruleConfig.earlyGraceMinutes }}分钟</el-descriptions-item>
        </el-descriptions>
      </template>
      <p class="form-note">窗口包含结束时刻所在的整分钟；宽限内不算异常，超过后记录完整迟到 / 早退分钟。重算始终采用以上快照，资料或当前规则修改不会改写快照。</p>
      <template #footer><el-button @click="detailOpen = false">关闭</el-button></template>
    </el-dialog>
  </div>
</template>

<script setup name="AttendanceDaily">
import { listDaily, getDaily, calculateDaily, recalculateDaily } from '@/api/attendance/daily'
import { siteOptions } from '@/api/attendance/site'
import { readDailyDashboardQuery } from '@/utils/attendanceDashboard'
const { proxy } = getCurrentInstance(), route = useRoute()
const states = { PENDING: { label: '待结算', type: 'info' }, REST: { label: '休息日', type: 'info' }, NORMAL: { label: '正常', type: 'success' }, ABNORMAL: { label: '异常', type: 'warning' } }
const query = reactive({ pageNum: 1, pageSize: 10, employeeNo: '', employeeName: '', siteId: undefined, resultStatus: '', abnormalType: '', resultGroup: '' })
const rows = ref([]), total = ref(0), loading = ref(false), selected = ref([]), sites = ref([]), dateRange = ref([]), showSearch = ref(true)
const filterSites = computed(() => query.siteId && !sites.value.some(s => s.id === query.siteId)
  ? [...sites.value, { id: query.siteId, label: rows.value.find(r => r.siteId === query.siteId)?.siteName || `场所 ${query.siteId}` }] : sites.value)
const calculateOpen = ref(false), calculating = ref(false), recalculating = ref(false), form = ref({}), calculateRef = ref(), detailOpen = ref(false), record = ref({})
const rules = { siteId: [{ required: true, message: '请选择办公场所', trigger: 'change' }], attendanceDate: [{ required: true, message: '请选择考勤日期', trigger: 'change' }] }
const duration = minutes => minutes == null ? '—' : `${Math.floor(minutes / 60)}小时${minutes % 60 ? minutes % 60 + '分钟' : ''}`
const workLabel = row => row.resultStatus === 'PENDING' ? '待结算' : row.workMinutes == null ? '待确认' : duration(row.workMinutes)
const weekLabel = days => days.split(',').map(d => ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][Number(d) - 1]).join('、')
function anomalies(row) { const labels = []; if (row.lateMinutes > 0) labels.push(`迟到${row.lateMinutes}分钟`); if (row.earlyMinutes > 0) labels.push(`早退${row.earlyMinutes}分钟`); if (row.missingIn) labels.push('上班缺卡'); if (row.missingOut) labels.push('下班缺卡'); return labels }
async function load() { loading.value = true; try { const r = await listDaily({ ...query, beginDate: dateRange.value?.[0], endDate: dateRange.value?.[1] }); rows.value = r.rows; total.value = r.total; selected.value = [] } finally { loading.value = false } }
async function loadSites(keyword = '') { sites.value = (await siteOptions(keyword)).data }
function search() { query.pageNum = 1; load() }
function resetQuery() { proxy.resetForm('queryRef'); dateRange.value = []; search() }
async function openCalculate() { await loadSites(); form.value = { siteId: query.siteId, attendanceDate: undefined }; calculateOpen.value = true; nextTick(() => calculateRef.value?.clearValidate()) }
async function calculate() {
  if (calculating.value) return
  calculating.value = true
  try {
    if (!await calculateRef.value.validate().catch(() => false)) return
    const r = await calculateDaily(form.value)
    proxy.$modal.msgSuccess(`计算完成：新增 ${r.data.created} 条，已有结果跳过 ${r.data.skipped} 条`)
    query.siteId = form.value.siteId; query.pageNum = 1; dateRange.value = [form.value.attendanceDate, form.value.attendanceDate]; calculateOpen.value = false; await load()
  } finally { calculating.value = false }
}
async function recalculate(ids) {
  if (recalculating.value) return
  if (ids.length > 100) return proxy.$modal.msgWarning('每次最多重算100条')
  try { await proxy.$modal.confirm(`确认按各自首次保存的规则快照重算这 ${ids.length} 条结果？当前规则修改不会用于本次重算。`) } catch { return }
  recalculating.value = true
  try { await recalculateDaily(ids); proxy.$modal.msgSuccess('按快照重算完成'); await load() } finally { recalculating.value = false }
}
async function detail(row) { record.value = (await getDaily(row.resultId)).data; detailOpen.value = true }
function applyRoute() {
  if (route.path !== '/attendance/daily') return
  const { dateRange: range, ...filters } = readDailyDashboardQuery(route.query)
  Object.assign(query, { pageNum: 1, employeeNo: '', employeeName: '', ...filters })
  dateRange.value = range
  load()
}
loadSites()
watch(() => [route.path, route.query], applyRoute, { immediate: true })
</script>

<style scoped>.daily-notice { margin-bottom: 20px; } .anomaly { margin: 2px 4px 2px 0; } .form-note { color: var(--el-text-color-secondary); line-height: 1.8; font-size: 13px; }</style>
