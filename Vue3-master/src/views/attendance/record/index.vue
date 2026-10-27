<template>
  <div class="app-container">
    <el-form ref="queryRef" :inline="true" :model="query" v-show="showSearch">
      <el-form-item label="工号" prop="employeeNo"><el-input v-model="query.employeeNo" clearable @keyup.enter="search" style="width: 155px" /></el-form-item>
      <el-form-item label="姓名" prop="employeeName"><el-input v-model="query.employeeName" clearable @keyup.enter="search" style="width: 155px" /></el-form-item>
      <el-form-item label="场次编号" prop="sessionId"><el-input-number v-model="query.sessionId" :min="1" :controls="false" style="width: 130px" /></el-form-item>
      <el-form-item label="办公场所" prop="siteId"><el-select v-model="query.siteId" filterable remote :remote-method="loadSites" clearable style="width: 220px"><el-option v-for="s in sites" :key="s.id" :label="s.label" :value="s.id" /></el-select></el-form-item>
      <el-form-item label="签到日期"><el-date-picker v-model="dateRange" type="daterange" value-format="YYYY-MM-DD" start-placeholder="开始日期" end-placeholder="结束日期" style="width: 260px" /></el-form-item>
      <el-form-item><el-button type="primary" icon="Search" @click="search">搜索</el-button><el-button icon="Refresh" @click="resetQuery">重置</el-button></el-form-item>
    </el-form>
    <el-row class="mb8"><el-text type="info">显示已成功保存的原始签到记录</el-text><right-toolbar v-model:showSearch="showSearch" @queryTable="load" /></el-row>
    <el-table v-loading="loading" :data="rows">
      <el-table-column label="记录编号" prop="recordId" width="100" />
      <el-table-column label="工号" prop="employeeNo" min-width="120" show-overflow-tooltip />
      <el-table-column label="姓名" prop="employeeName" min-width="100" />
      <el-table-column label="部门" prop="deptName" min-width="130" show-overflow-tooltip />
      <el-table-column label="场所" prop="siteName" min-width="160" show-overflow-tooltip />
      <el-table-column label="签到场次" prop="sessionTitle" min-width="180" show-overflow-tooltip />
      <el-table-column label="签到时间" prop="checkinTime" width="180" />
      <el-table-column label="方式" width="130"><template #default="{row}">{{ row.checkinMethod === 'QR_FACE' ? '扫码＋人脸核验' : '扫码' }}</template></el-table-column>
      <el-table-column label="操作" width="90" fixed="right"><template #default="{ row }"><el-button link type="primary" @click="detail(row)" v-hasPermi="['attendance:record:query']">详情</el-button></template></el-table-column>
    </el-table>
    <pagination v-show="total > 0" :total="total" v-model:page="query.pageNum" v-model:limit="query.pageSize" @pagination="load" />
    <el-dialog v-model="detailOpen" title="签到记录详情" width="min(700px, 94vw)" append-to-body>
      <el-descriptions :column="2" border>
        <el-descriptions-item label="记录编号">{{ record.recordId }}</el-descriptions-item><el-descriptions-item label="场次编号">{{ record.sessionId }}</el-descriptions-item>
        <el-descriptions-item label="工号">{{ record.employeeNo }}</el-descriptions-item><el-descriptions-item label="姓名">{{ record.employeeName }}</el-descriptions-item>
        <el-descriptions-item label="系统账号">{{ record.userName }}</el-descriptions-item><el-descriptions-item label="所属部门">{{ record.deptName }}</el-descriptions-item>
        <el-descriptions-item label="办公场所" :span="2">{{ record.siteName }}</el-descriptions-item>
        <el-descriptions-item label="签到场次" :span="2">{{ record.sessionTitle }}</el-descriptions-item>
        <el-descriptions-item label="签到时间">{{ record.checkinTime }}</el-descriptions-item><el-descriptions-item label="签到方式">{{ record.checkinMethod === 'QR_FACE' ? '扫码＋人脸核验' : '扫码' }}</el-descriptions-item>
      </el-descriptions>
      <p v-if="verification">虹软核验分数 {{ Number(verification.score).toFixed(4) }}，阈值 {{ verification.threshold }}，人脸档案版本 {{ verification.profileVersion }}。未包含活体检测。</p>
      <template #footer><el-button @click="detailOpen = false">关闭</el-button></template>
    </el-dialog>
  </div>
</template>
<script setup name="AttendanceRecord">
import { listRecord, getRecord } from '@/api/attendance/checkin'
import { faceVerification } from '@/api/attendance/face'
import { siteOptions } from '@/api/attendance/site'
const { proxy } = getCurrentInstance(), route = useRoute()
const query = reactive({ pageNum: 1, pageSize: 10, employeeNo: '', employeeName: '', siteId: undefined, sessionId: route.query.sessionId ? Number(route.query.sessionId) : undefined })
const rows = ref([]), sites = ref([]), total = ref(0), loading = ref(false), dateRange = ref([]), showSearch = ref(true), detailOpen = ref(false), record = ref({})
const verification = ref(null)
async function load() { loading.value = true; try { const r = await listRecord({ ...query, beginDate: dateRange.value?.[0], endDate: dateRange.value?.[1] }); rows.value = r.rows; total.value = r.total } finally { loading.value = false } }
async function loadSites(keyword = '') { sites.value = (await siteOptions(keyword)).data }
function search() { query.pageNum = 1; load() }
function resetQuery() { proxy.resetForm('queryRef'); dateRange.value = []; query.sessionId = undefined; search() }
let detailVersion = 0
async function detail(row) {
  const current = ++detailVersion
  verification.value = null
  const r = await getRecord(row.recordId)
  if (current !== detailVersion) return
  record.value = r.data; detailOpen.value = true
  if (record.value.checkinMethod === 'QR_FACE') {
    const v = await faceVerification(row.recordId)
    if (current === detailVersion) verification.value = v.data
  }
}
loadSites(); load()
</script>
