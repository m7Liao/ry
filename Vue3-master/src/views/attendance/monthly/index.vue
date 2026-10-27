<template>
  <div class="app-container">
    <el-form :inline="true" v-show="showSearch" @submit.prevent="search">
      <el-form-item label="月份"><el-date-picker v-model="query.month" type="month" value-format="YYYY-MM" :clearable="false" style="width:150px" /></el-form-item>
      <el-form-item label="工号"><el-input v-model="query.employeeNo" clearable maxlength="32" @keyup.enter="search" style="width:150px" /></el-form-item>
      <el-form-item label="姓名"><el-input v-model="query.employeeName" clearable maxlength="50" @keyup.enter="search" style="width:150px" /></el-form-item>
      <el-form-item><el-button type="primary" icon="Search" @click="search">查询</el-button><el-button icon="Refresh" @click="reset">重置</el-button></el-form-item>
    </el-form>
    <el-alert type="info" :closable="false" show-icon class="mb16" title="仅汇总所选月份已生成、且在本人数据权限内的每日结果。未生成日期不代表缺勤；本月统计至今天。缺卡与待结算工时不计入已确认工时。" />
    <el-row class="mb8"><right-toolbar v-model:showSearch="showSearch" @queryTable="load" /></el-row>
    <el-table v-loading="loading" :data="rows" border>
      <el-table-column label="工号" prop="employeeNo" fixed min-width="130" show-overflow-tooltip />
      <el-table-column label="姓名" prop="employeeName" fixed min-width="110" show-overflow-tooltip />
      <el-table-column label="部门快照" prop="deptName" min-width="140" show-overflow-tooltip />
      <el-table-column v-for="c in columns" :key="c.key" :label="c.label" :prop="c.key" width="100" align="center" />
      <el-table-column label="计划工时(h)" width="125" align="right"><template #default="{row}">{{ hours(row.plannedWorkMinutes) }}</template></el-table-column>
      <el-table-column label="已确认工时(h)" width="140" align="right"><template #default="{row}">{{ hours(row.workMinutes) }}</template></el-table-column>
      <el-table-column label="工时待确认(天)" prop="unknownWorkDays" width="145" align="center" />
      <el-table-column label="迟到(分钟)" prop="lateMinutes" width="110" align="center" />
      <el-table-column label="早退(分钟)" prop="earlyMinutes" width="110" align="center" />
    </el-table>
    <pagination v-show="total>0" :total="total" v-model:page="query.pageNum" v-model:limit="query.pageSize" @pagination="load" />
    <p class="hint">双缺卡每天计1个缺卡日；迟到、早退、缺卡可以重叠，不能相加作为异常天数。“完整打卡”指已结算且上下班记录完整，不等同于正常。“计划工时”含已生成待结算日，不能与部分已确认工时直接比较。姓名和部门取当前查询范围内最近创建结果的快照。</p>
  </div>
</template>
<script setup name="AttendanceMonthly">
import { listMonthly } from '@/api/attendance/monthly'
import { shanghaiMonth, hours } from '@/utils/attendanceMonthly'
const initial = () => ({ month: shanghaiMonth(), employeeNo: '', employeeName: '', pageNum: 1, pageSize: 10 })
const query = reactive(initial()), rows = ref([]), total = ref(0), loading = ref(false), showSearch = ref(true)
const columns = [
  { key: 'generatedDays', label: '已生成(天)' }, { key: 'workDays', label: '工作日(天)' },
  { key: 'settledDays', label: '已结算(天)' }, { key: 'attendedDays', label: '完整打卡(天)' },
  { key: 'normalDays', label: '正常(天)' }, { key: 'abnormalDays', label: '异常(天)' },
  { key: 'missingDays', label: '缺卡(天)' }, { key: 'lateDays', label: '迟到(天)' },
  { key: 'earlyDays', label: '早退(天)' }, { key: 'pendingDays', label: '待结算(天)' }, { key: 'restDays', label: '休息日(天)' }
]
let version = 0
async function load() {
  const current = ++version; loading.value = true
  try { const r = await listMonthly(query); if (version === current) { rows.value = r.rows; total.value = r.total } }
  catch (e) { if (version === current) { rows.value = []; total.value = 0 } }
  finally { if (version === current) loading.value = false }
}
function search() { query.pageNum = 1; load() }
function reset() { Object.assign(query, initial()); load() }
load()
</script>
<style scoped>.mb16 { margin-bottom:16px; } .hint { color:var(--el-text-color-secondary); font-size:13px; line-height:1.8; }</style>
