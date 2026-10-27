<template>
  <div class="app-container">
    <el-form ref="queryRef" :model="query" :inline="true" v-show="showSearch">
      <el-form-item label="场所编码" prop="siteCode"><el-input v-model="query.siteCode" clearable @keyup.enter="search" style="width: 170px" /></el-form-item>
      <el-form-item label="场所名称" prop="siteName"><el-input v-model="query.siteName" clearable @keyup.enter="search" style="width: 180px" /></el-form-item>
      <el-form-item label="管理部门" prop="deptId"><el-select v-model="query.deptId" clearable filterable style="width: 180px"><el-option v-for="d in departments" :key="d.id" :label="d.label" :value="d.id" /></el-select></el-form-item>
      <el-form-item label="状态" prop="status"><el-select v-model="query.status" clearable style="width: 120px"><el-option label="启用" value="0" /><el-option label="停用" value="1" /></el-select></el-form-item>
      <el-form-item><el-button type="primary" icon="Search" @click="search">搜索</el-button><el-button icon="Refresh" @click="resetQuery">重置</el-button></el-form-item>
    </el-form>
    <el-row class="mb8" :gutter="10">
      <el-col :span="1.5"><el-button type="primary" plain icon="Plus" v-hasPermi="['attendance:site:add']" @click="openAdd">新增场所</el-button></el-col>
      <el-col :span="1.5"><el-button type="danger" plain icon="Delete" v-hasPermi="['attendance:site:remove']" :disabled="!selected.length" @click="removeSelected">批量删除</el-button></el-col>
      <right-toolbar v-model:showSearch="showSearch" @queryTable="load" />
    </el-row>
    <el-table v-loading="loading" :data="rows" @selection-change="selection => selected = selection.map(s => s.siteId)">
      <el-table-column type="selection" width="48" />
      <el-table-column label="场所ID" prop="siteId" width="90" />
      <el-table-column label="场所编码" prop="siteCode" min-width="130" show-overflow-tooltip />
      <el-table-column label="场所名称" prop="siteName" min-width="160" show-overflow-tooltip />
      <el-table-column label="管理部门" prop="deptName" min-width="130" />
      <el-table-column label="详细地址" prop="address" min-width="220" show-overflow-tooltip />
      <el-table-column label="绑定人数" prop="employeeCount" width="95" align="center" />
      <el-table-column label="状态" width="90"><template #default="{ row }"><el-tag :type="row.status === '0' ? 'success' : 'info'">{{ row.status === '0' ? '启用' : '停用' }}</el-tag></template></el-table-column>
      <el-table-column label="操作" width="350" fixed="right"><template #default="{ row }">
        <el-button link type="primary" v-hasPermi="['attendance:rule:list']" @click="$router.push({ path: '/attendance/rule', query: { siteId: row.siteId } })">考勤规则</el-button>
        <el-button link type="primary" v-hasPermi="['attendance:session:list']" @click="$router.push({ path: '/attendance/session', query: { siteId: row.siteId } })">签到场次</el-button>
        <el-button link type="primary" v-hasPermi="['attendance:site:query']" @click="openEdit(row, true)">详情</el-button>
        <el-button link type="primary" v-hasPermi="['attendance:site:edit']" @click="openEdit(row)">修改</el-button>
        <el-button link type="danger" v-hasPermi="['attendance:site:remove']" @click="remove([row.siteId])">删除</el-button>
      </template></el-table-column>
    </el-table>
    <pagination v-show="total > 0" :total="total" v-model:page="query.pageNum" v-model:limit="query.pageSize" @pagination="load" />

    <el-dialog v-model="open" :title="readonly ? '办公场所详情' : form.siteId ? '修改办公场所' : '新增办公场所'" width="720px" append-to-body :close-on-click-modal="false" @closed="clearValidation">
      <el-form ref="formRef" :model="form" :rules="rules" label-width="100px" :disabled="readonly || saving">
        <el-row :gutter="20">
          <el-col :span="12"><el-form-item label="场所编码" prop="siteCode"><el-input v-model.trim="form.siteCode" maxlength="32" placeholder="如 HQ_001" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="场所名称" prop="siteName"><el-input v-model.trim="form.siteName" maxlength="100" /></el-form-item></el-col>
        </el-row>
        <el-form-item label="管理部门" prop="deptId"><el-select v-model="form.deptId" filterable style="width: 100%"><el-option v-for="d in formDepartments" :key="d.id" :label="d.label" :value="d.id" :disabled="d.status === '1'" /></el-select></el-form-item>
        <el-form-item label="详细地址" prop="address"><el-input v-model.trim="form.address" maxlength="255" /></el-form-item>
        <el-row :gutter="20">
          <el-col :span="12"><el-form-item label="经度" prop="longitude"><el-input-number v-model="form.longitude" :min="-180" :max="180" :precision="6" :controls="false" placeholder="可留空" style="width: 100%" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="纬度" prop="latitude"><el-input-number v-model="form.latitude" :min="-90" :max="90" :precision="6" :controls="false" placeholder="可留空" style="width: 100%" /></el-form-item></el-col>
        </el-row>
        <el-form-item label="坐标系" prop="coordinateSystem"><el-select v-model="form.coordinateSystem"><el-option label="GCJ02（高德 / 腾讯）" value="GCJ02" /><el-option label="WGS84（GPS）" value="WGS84" /><el-option label="BD09（百度）" value="BD09" /></el-select></el-form-item>
        <p class="form-tip">坐标需成对填写，也可同时留空；请确认来源坐标系。本页暂不提供地图选点和坐标转换。</p>
        <el-row :gutter="20">
          <el-col :span="12"><el-form-item label="联系人" prop="contactName"><el-input v-model="form.contactName" maxlength="50" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="联系电话" prop="contactPhone"><el-input v-model.trim="form.contactPhone" maxlength="30" /></el-form-item></el-col>
        </el-row>
        <el-form-item label="状态" prop="status"><el-radio-group v-model="form.status"><el-radio value="0">启用</el-radio><el-radio value="1">停用</el-radio></el-radio-group></el-form-item>
        <el-form-item label="备注" prop="remark"><el-input v-model="form.remark" type="textarea" maxlength="500" show-word-limit :rows="3" /></el-form-item>
      </el-form>
      <template #footer><el-button @click="open = false">{{ readonly ? '关闭' : '取消' }}</el-button><el-button v-if="!readonly" type="primary" :loading="saving" @click="save">保存</el-button></template>
    </el-dialog>
  </div>
</template>

<script setup name="AttendanceSite">
import { listSite, getSite, addSite, updateSite, deleteSite, departmentOptions } from '@/api/attendance/site'
const { proxy } = getCurrentInstance()
const query = reactive({ pageNum: 1, pageSize: 10, siteCode: '', siteName: '', deptId: undefined, status: '' })
const rows = ref([]), total = ref(0), loading = ref(false), showSearch = ref(true), selected = ref([])
const departments = ref([]), open = ref(false), readonly = ref(false), saving = ref(false), form = ref({}), formRef = ref()
const formDepartments = computed(() => form.value.deptId && !departments.value.some(d => d.id === form.value.deptId)
  ? [...departments.value, { id: form.value.deptId, label: `${form.value.deptName || '原管理部门'}（不可用，请更换）`, status: '1' }] : departments.value)
const required = message => ({ required: true, message, trigger: 'blur' })
const pairValidator = (_, value, callback) => {
  const hasLon = form.value.longitude !== undefined && form.value.longitude !== null
  const hasLat = form.value.latitude !== undefined && form.value.latitude !== null
  callback(hasLon !== hasLat ? new Error('经度和纬度必须同时填写或同时留空') : undefined)
}
const rules = {
  siteCode: [required('请输入场所编码'), { pattern: /^[A-Za-z0-9_-]+$/, message: '只能包含字母、数字、下划线和短横线', trigger: 'blur' }],
  siteName: [required('请输入场所名称')], deptId: [required('请选择管理部门')], address: [required('请输入详细地址')],
  longitude: [{ validator: pairValidator, trigger: 'change' }], latitude: [{ validator: pairValidator, trigger: 'change' }],
  contactPhone: [{ pattern: /^[0-9+() -]*$/, message: '联系电话格式不正确', trigger: 'blur' }]
}
async function load() {
  loading.value = true
  try { const response = await listSite(query); rows.value = response.rows; total.value = response.total; selected.value = [] }
  finally { loading.value = false }
}
function search() { query.pageNum = 1; load() }
function resetQuery() { proxy.resetForm('queryRef'); search() }
function clearValidation() { formRef.value?.clearValidate() }
async function refreshDepartments() { departments.value = (await departmentOptions()).data }
async function openAdd() {
  await refreshDepartments()
  form.value = { siteCode: '', siteName: '', deptId: undefined, address: '', longitude: undefined, latitude: undefined, coordinateSystem: 'GCJ02', contactName: '', contactPhone: '', status: '0', remark: '' }
  readonly.value = false; open.value = true; nextTick(clearValidation)
}
async function openEdit(row, viewOnly = false) {
  const response = await getSite(row.siteId)
  if (!viewOnly) await refreshDepartments()
  form.value = response.data; readonly.value = viewOnly; open.value = true; nextTick(clearValidation)
}
async function save() {
  if (!await formRef.value.validate().catch(() => false)) return
  saving.value = true
  try { await (form.value.siteId ? updateSite(form.value) : addSite(form.value)); proxy.$modal.msgSuccess('保存成功'); open.value = false; await load() }
  finally { saving.value = false }
}
function removeSelected() { remove(selected.value) }
async function remove(ids) {
  if (ids.length > 100) return proxy.$modal.msgWarning('每次最多删除100条')
  try { await proxy.$modal.confirm(`确认删除这 ${ids.length} 个办公场所？仍绑定员工的场所无法删除。`) } catch { return }
  await deleteSite(ids); proxy.$modal.msgSuccess('删除成功'); await load()
}
refreshDepartments()
load()
</script>
<style scoped>.form-tip { color: var(--el-text-color-secondary); font-size: 12px; margin: -5px 0 18px 100px; line-height: 1.7; }</style>
