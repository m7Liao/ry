<template>
  <div class="app-container">
    <el-alert class="scope-notice" title="当前用于保存固定班次参数和预览计划工时；扫码签到仍按场次开放时间校验，尚未自动计算迟到、早退、缺卡和实际工时。" type="info" :closable="false" show-icon />
    <el-form ref="queryRef" :model="query" :inline="true" v-show="showSearch">
      <el-form-item label="规则名称" prop="ruleName"><el-input v-model="query.ruleName" clearable style="width: 200px" @keyup.enter="search" /></el-form-item>
      <el-form-item label="办公场所" prop="siteId"><el-select v-model="query.siteId" filterable remote :remote-method="loadSites" clearable style="width: 230px"><el-option v-for="s in sites" :key="s.id" :label="s.label" :value="s.id" /></el-select></el-form-item>
      <el-form-item label="规则状态" prop="status"><el-select v-model="query.status" clearable style="width: 120px"><el-option label="启用" value="0" /><el-option label="停用" value="1" /></el-select></el-form-item>
      <el-form-item><el-button type="primary" icon="Search" @click="search">搜索</el-button><el-button icon="Refresh" @click="resetQuery">重置</el-button></el-form-item>
    </el-form>
    <el-row class="mb8"><el-button type="primary" plain icon="Plus" v-hasPermi="['attendance:rule:add']" @click="openAdd">新增规则</el-button><right-toolbar v-model:showSearch="showSearch" @queryTable="load" /></el-row>
    <el-table v-loading="loading" :data="rows">
      <el-table-column label="规则名称" prop="ruleName" min-width="150" show-overflow-tooltip />
      <el-table-column label="办公场所" prop="siteName" min-width="150" show-overflow-tooltip><template #default="{ row }">{{ row.siteName }}<el-tag v-if="row.siteStatus === '1'" type="info" size="small">场所停用</el-tag></template></el-table-column>
      <el-table-column label="管理部门" prop="deptName" min-width="120" />
      <el-table-column label="工作日" min-width="170"><template #default="{ row }">{{ weekLabel(row.workDays) }}</template></el-table-column>
      <el-table-column label="上下班" width="160"><template #default="{ row }">{{ row.startTime }} ～ {{ row.endNextDay === '1' ? '次日 ' : '' }}{{ row.endTime }}</template></el-table-column>
      <el-table-column label="计划工时" width="110"><template #default="{ row }">{{ durationLabel(row.plannedWorkMinutes) }}</template></el-table-column>
      <el-table-column label="规则状态" width="90"><template #default="{ row }"><el-tag :type="row.status === '0' ? 'success' : 'info'">{{ row.status === '0' ? '启用' : '停用' }}</el-tag></template></el-table-column>
      <el-table-column label="操作" width="185" fixed="right"><template #default="{ row }">
        <el-button link type="primary" v-hasPermi="['attendance:rule:query']" @click="openEdit(row, true)">详情</el-button>
        <el-button link type="primary" v-hasPermi="['attendance:rule:edit']" @click="openEdit(row)">修改</el-button>
        <el-button link type="danger" v-hasPermi="['attendance:rule:remove']" @click="remove(row)">删除</el-button>
      </template></el-table-column>
    </el-table>
    <pagination v-show="total > 0" :total="total" v-model:page="query.pageNum" v-model:limit="query.pageSize" @pagination="load" />

    <el-dialog v-model="open" :title="readonly ? '考勤规则详情' : form.ruleId ? '修改考勤规则' : '新增考勤规则'" width="min(800px, 96vw)" append-to-body :close-on-click-modal="false">
      <el-form ref="formRef" :model="form" :rules="rules" label-width="112px" :disabled="readonly || saving">
        <el-form-item label="办公场所" prop="siteId"><el-select v-model="form.siteId" filterable remote :remote-method="loadSites" :disabled="!!form.ruleId" style="width: 100%" placeholder="每个办公场所只配置一套规则"><el-option v-for="s in formSites" :key="s.id" :label="s.label" :value="s.id" :disabled="s.status !== '0'" /></el-select></el-form-item>
        <el-form-item label="规则名称" prop="ruleName"><el-input v-model.trim="form.ruleName" maxlength="100" placeholder="例如：总部标准班次" /></el-form-item>
        <el-form-item label="每周工作日" prop="workDays"><el-checkbox-group v-model="form.workDays"><el-checkbox v-for="(label, i) in weekNames" :key="i" :value="String(i + 1)">{{ label }}</el-checkbox></el-checkbox-group></el-form-item>
        <el-row :gutter="16">
          <el-col :xs="24" :sm="12"><el-form-item label="上班时间" prop="startTime"><el-time-picker v-model="form.startTime" format="HH:mm" value-format="HH:mm" :clearable="false" style="width: 100%" /></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="下班时间" prop="endTime"><el-time-picker v-model="form.endTime" format="HH:mm" value-format="HH:mm" :clearable="false" style="width: 100%" /></el-form-item></el-col>
        </el-row>
        <el-form-item label="下班日期" prop="endNextDay"><el-radio-group v-model="form.endNextDay"><el-radio value="0">当天</el-radio><el-radio value="1">次日</el-radio></el-radio-group></el-form-item>
        <el-row :gutter="16">
          <el-col :xs="24" :sm="12"><el-form-item label="迟到宽限" prop="lateGraceMinutes"><el-input-number v-model="form.lateGraceMinutes" :min="0" :max="180" :precision="0" /> <span class="unit">分钟</span></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="早退宽限" prop="earlyGraceMinutes"><el-input-number v-model="form.earlyGraceMinutes" :min="0" :max="180" :precision="0" /> <span class="unit">分钟</span></el-form-item></el-col>
        </el-row>
        <el-divider content-position="left">打卡窗口</el-divider>
        <el-row :gutter="16">
          <el-col v-for="item in windowFields" :key="item.key" :xs="24" :sm="12"><el-form-item :label="item.label" :prop="item.key"><el-input-number v-model="form[item.key]" :min="0" :max="360" :precision="0" /> <span class="unit">分钟</span></el-form-item></el-col>
        </el-row>
        <el-row :gutter="16">
          <el-col :xs="24" :sm="12"><el-form-item label="固定休息时长" prop="restMinutes"><el-input-number v-model="form.restMinutes" :min="0" :max="720" :precision="0" /> <span class="unit">分钟</span></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="规则状态" prop="status"><el-radio-group v-model="form.status"><el-radio value="0">启用</el-radio><el-radio value="1">停用</el-radio></el-radio-group></el-form-item></el-col>
        </el-row>
        <el-form-item label="备注"><el-input v-model="form.remark" type="textarea" :rows="2" maxlength="500" show-word-limit /></el-form-item>
      </el-form>
      <div class="rule-preview" aria-live="polite">
        <strong>规则预览</strong>
        <p v-if="preview.error" class="preview-error">{{ preview.error }}</p>
        <template v-else><p>上班打卡：{{ preview.startWindow }}</p><p>下班打卡：{{ preview.endWindow }}</p><p>计划工时：{{ durationLabel(preview.minutes) }}（班次时长减固定休息时长）</p></template>
        <p class="preview-note">跨天班次按上班当天对应星期配置工作日。这里展示计划时长，实际工时需结合打卡与后续考勤计算确定。</p>
      </div>
      <template #footer><el-button @click="open = false">{{ readonly ? '关闭' : '取消' }}</el-button><el-button v-if="!readonly" type="primary" :loading="saving" @click="save">保存</el-button></template>
    </el-dialog>
  </div>
</template>

<script setup name="AttendanceRule">
import { listRule, getRule, addRule, updateRule, deleteRule } from '@/api/attendance/rule'
import { siteOptions } from '@/api/attendance/site'
const { proxy } = getCurrentInstance()
const route = useRoute()
const query = reactive({ pageNum: 1, pageSize: 10, ruleName: '', siteId: route.query.siteId ? Number(route.query.siteId) : undefined, status: '' })
const rows = ref([]), total = ref(0), loading = ref(false), showSearch = ref(true), sites = ref([])
const open = ref(false), readonly = ref(false), saving = ref(false), form = ref({}), formRef = ref()
const weekNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
const windowFields = [{ key: 'startBeforeMinutes', label: '上班前可打卡' }, { key: 'startAfterMinutes', label: '上班后可打卡' }, { key: 'endBeforeMinutes', label: '下班前可打卡' }, { key: 'endAfterMinutes', label: '下班后可打卡' }]
const formSites = computed(() => form.value.siteId && !sites.value.some(s => s.id === form.value.siteId) ? [...sites.value, { id: form.value.siteId, label: `${form.value.siteName || '已选场所'} / ${form.value.siteCode || form.value.siteId}`, status: form.value.siteStatus || '0' }] : sites.value)
const required = message => ({ required: true, message, trigger: 'change' })
const rules = { siteId: [required('请选择办公场所')], ruleName: [{ required: true, whitespace: true, message: '请输入规则名称', trigger: 'blur' }], workDays: [{ type: 'array', required: true, min: 1, message: '请至少选择一个工作日', trigger: 'change' }], startTime: [required('请选择上班时间')], endTime: [required('请选择下班时间')] }
for (const key of ['lateGraceMinutes', 'earlyGraceMinutes', 'restMinutes', ...windowFields.map(f => f.key)]) rules[key] = [required('请填写分钟数')]
const durationLabel = minutes => `${Math.floor(minutes / 60)}小时${minutes % 60 ? minutes % 60 + '分钟' : ''}`
const weekLabel = days => days.split(',').map(d => weekNames[Number(d) - 1]).join('、')
const clock = minutes => { const day = Math.floor(minutes / 1440), time = ((minutes % 1440) + 1440) % 1440; return `${day < 0 ? '前一日' : day === 0 ? '当日' : day === 1 ? '次日' : '后两日'} ${String(Math.floor(time / 60)).padStart(2, '0')}:${String(time % 60).padStart(2, '0')}` }
const preview = computed(() => {
  const f = form.value, toMinute = t => /^([01]\d|2[0-3]):[0-5]\d$/.test(t || '') ? Number(t.slice(0, 2)) * 60 + Number(t.slice(3)) : NaN
  const start = toMinute(f.startTime), end = toMinute(f.endTime) + (f.endNextDay === '1' ? 1440 : 0)
  const keys = ['lateGraceMinutes', 'earlyGraceMinutes', 'restMinutes', ...windowFields.map(w => w.key)]
  if (!Number.isFinite(start) || !Number.isFinite(end) || keys.some(k => !Number.isInteger(f[k]))) return { error: '请填写完整时间和分钟数。' }
  if (end <= start || end - start > 1440) return { error: '班次时长必须大于0且不超过24小时，请检查下班日期。' }
  if (f.restMinutes >= end - start) return { error: '休息时长必须小于班次时长。' }
  if (start + f.startAfterMinutes >= end - f.endBeforeMinutes) return { error: '上班和下班打卡窗口不能重叠或相接。' }
  if (f.lateGraceMinutes > f.startAfterMinutes || f.earlyGraceMinutes > f.endBeforeMinutes) return { error: '迟到、早退宽限必须位于对应打卡窗口内。' }
  return { minutes: end - start - f.restMinutes, startWindow: `${clock(start - f.startBeforeMinutes)} ～ ${clock(start + f.startAfterMinutes)}`, endWindow: `${clock(end - f.endBeforeMinutes)} ～ ${clock(end + f.endAfterMinutes)}` }
})
async function load() { loading.value = true; try { const r = await listRule(query); rows.value = r.rows; total.value = r.total } finally { loading.value = false } }
async function loadSites(keyword = '') { sites.value = (await siteOptions(keyword)).data }
function search() { query.pageNum = 1; load() }
function resetQuery() { proxy.resetForm('queryRef'); search() }
async function openAdd() {
  await loadSites()
  form.value = { siteId: query.siteId, ruleName: '', workDays: ['1', '2', '3', '4', '5'], startTime: '09:00', endTime: '18:00', endNextDay: '0', lateGraceMinutes: 5, earlyGraceMinutes: 0, startBeforeMinutes: 60, startAfterMinutes: 60, endBeforeMinutes: 60, endAfterMinutes: 120, restMinutes: 60, status: '0', remark: '' }
  readonly.value = false; open.value = true; nextTick(() => formRef.value?.clearValidate())
}
async function openEdit(row, viewOnly = false) { const r = await getRule(row.ruleId); form.value = { ...r.data, workDays: r.data.workDays.split(',') }; readonly.value = viewOnly; open.value = true; nextTick(() => formRef.value?.clearValidate()) }
async function save() {
  if (saving.value) return
  saving.value = true
  try {
    if (!await formRef.value.validate().catch(() => false)) return
    if (preview.value.error) return proxy.$modal.msgWarning(preview.value.error)
    const data = { ...form.value, workDays: [...form.value.workDays].sort().join(',') }
    await (data.ruleId ? updateRule(data) : addRule(data)); proxy.$modal.msgSuccess('规则配置已保存'); open.value = false; await load()
  } finally { saving.value = false }
}
async function remove(row) { try { await proxy.$modal.confirm(`确认删除“${row.ruleName}”的配置？原始签到记录将保留。`) } catch { return }; await deleteRule(row.ruleId); proxy.$modal.msgSuccess('删除成功'); await load() }
loadSites(); load()
</script>

<style scoped>
.scope-notice { margin-bottom: 20px; }
.unit { margin-left: 6px; }
.rule-preview { padding: 16px 20px; background: var(--el-fill-color-light); border-radius: 4px; line-height: 1.6; }
.rule-preview p { margin: 8px 0 0; }
.preview-error { color: var(--el-color-danger); }
.preview-note { color: var(--el-text-color-secondary); font-size: 12px; }
</style>
