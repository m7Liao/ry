<template>
  <div class="app-container">
    <el-alert title="先在系统管理中建立账号，再创建员工档案。每个账号对应一份档案，每名员工绑定一个主要办公场所。" type="info" :closable="false" show-icon class="mb16" />
    <el-form ref="queryRef" :model="query" :inline="true" v-show="showSearch">
      <el-form-item label="工号" prop="employeeNo"><el-input v-model="query.employeeNo" clearable @keyup.enter="search" style="width: 150px" /></el-form-item>
      <el-form-item label="姓名" prop="employeeName"><el-input v-model="query.employeeName" clearable @keyup.enter="search" style="width: 150px" /></el-form-item>
      <el-form-item label="所属部门" prop="deptId"><el-select v-model="query.deptId" filterable clearable style="width: 180px"><el-option v-for="d in departments" :key="d.id" :label="d.label" :value="d.id" /></el-select></el-form-item>
      <el-form-item label="办公场所" prop="siteId"><el-select v-model="query.siteId" clearable filterable remote :remote-method="searchSites" :loading="sitesLoading" placeholder="输入场所名称搜索" style="width: 200px"><el-option v-for="s in sites" :key="s.id" :label="s.label" :value="s.id" /></el-select></el-form-item>
      <el-form-item label="状态" prop="status"><el-select v-model="query.status" clearable style="width: 110px"><el-option label="在职" value="0" /><el-option label="离职" value="1" /></el-select></el-form-item>
      <el-form-item><el-button type="primary" icon="Search" @click="search">搜索</el-button><el-button icon="Refresh" @click="resetQuery">重置</el-button></el-form-item>
    </el-form>
    <el-row :gutter="10" class="mb8">
      <el-col :span="1.5"><el-button type="primary" plain icon="Plus" @click="openAdd" v-hasPermi="['attendance:employee:add']">新增员工</el-button></el-col>
      <el-col :span="1.5"><el-button type="danger" plain icon="Delete" :disabled="!selected.length" @click="remove(selected)" v-hasPermi="['attendance:employee:remove']">批量删除</el-button></el-col>
      <right-toolbar v-model:showSearch="showSearch" @queryTable="load" />
    </el-row>
    <el-table :data="rows" v-loading="loading" @selection-change="selection => selected = selection.map(e => e.employeeId)">
      <el-table-column type="selection" width="48" />
      <el-table-column label="工号" prop="employeeNo" min-width="120" show-overflow-tooltip />
      <el-table-column label="姓名" prop="employeeName" min-width="100" />
      <el-table-column label="系统账号" prop="userName" min-width="130"><template #default="{ row }">{{ row.userName }}<el-tag v-if="row.accountStatus !== '0'" size="small" type="warning">停用</el-tag></template></el-table-column>
      <el-table-column label="所属部门" prop="deptName" min-width="130" show-overflow-tooltip />
      <el-table-column label="办公场所" prop="siteName" min-width="170"><template #default="{ row }">{{ row.siteName }}<el-tag v-if="row.siteStatus !== '0'" size="small" type="warning">停用</el-tag></template></el-table-column>
      <el-table-column label="联系电话" prop="phone" min-width="135" />
      <el-table-column label="入职日期" prop="hireDate" width="115" />
      <el-table-column label="状态" width="90"><template #default="{ row }"><el-tag :type="row.status === '0' ? 'success' : 'info'">{{ row.status === '0' ? '在职' : '离职' }}</el-tag></template></el-table-column>
      <el-table-column label="操作" width="280" fixed="right"><template #default="{ row }">
        <el-button link type="primary" v-hasPermi="['attendance:face:query']" @click="faceDialog.show(row)">人脸档案</el-button>
        <el-button link type="primary" v-hasPermi="['attendance:employee:query']" @click="openEdit(row, true)">详情</el-button>
        <el-button link type="primary" v-hasPermi="['attendance:employee:edit']" @click="openEdit(row)">修改 / 绑定</el-button>
        <el-button link type="danger" v-hasPermi="['attendance:employee:remove']" @click="remove([row.employeeId])">删除</el-button>
      </template></el-table-column>
    </el-table>
    <pagination v-show="total > 0" :total="total" v-model:page="query.pageNum" v-model:limit="query.pageSize" @pagination="load" />
    <FaceDialog ref="faceDialog" />

    <el-dialog v-model="open" :title="readonly ? '员工档案详情' : form.employeeId ? '修改员工档案与场所绑定' : '新增员工档案'" width="720px" append-to-body :close-on-click-modal="false" @closed="clearValidation">
      <el-form ref="formRef" :model="form" :rules="rules" label-width="100px" :disabled="readonly || saving">
        <el-row :gutter="20">
          <el-col :span="12"><el-form-item label="工号" prop="employeeNo"><el-input v-model.trim="form.employeeNo" maxlength="32" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="员工姓名" prop="employeeName"><el-input v-model.trim="form.employeeName" maxlength="50" /></el-form-item></el-col>
        </el-row>
        <el-form-item label="系统账号" prop="userId">
          <el-input v-if="form.employeeId" :model-value="form.userName" disabled />
          <el-select v-else v-model="form.userId" filterable remote :remote-method="searchUsers" :loading="usersLoading" placeholder="搜索未绑定的启用账号" style="width: 100%" @change="selectUser"><el-option v-for="u in users" :key="u.id" :label="`${u.label} · ${u.deptName}`" :value="u.id" /></el-select>
        </el-form-item>
        <el-form-item label="所属部门"><el-input :model-value="form.deptName || '选择账号后自动显示'" disabled /></el-form-item>
        <el-form-item label="办公场所" prop="siteId"><el-select v-model="form.siteId" filterable remote :remote-method="searchSites" :loading="sitesLoading" placeholder="输入场所名称搜索" style="width: 100%"><el-option v-for="s in formSites" :key="s.id" :label="s.label" :value="s.id" :disabled="s.status === '1' && s.id !== originalSite?.id" /></el-select></el-form-item>
        <el-row :gutter="20">
          <el-col :span="12"><el-form-item label="联系电话" prop="phone"><el-input v-model.trim="form.phone" maxlength="30" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="邮箱" prop="email"><el-input v-model.trim="form.email" maxlength="100" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="入职日期" prop="hireDate"><el-date-picker v-model="form.hireDate" type="date" value-format="YYYY-MM-DD" style="width: 100%" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="员工状态" prop="status"><el-radio-group v-model="form.status" @change="changeStatus"><el-radio value="0">在职</el-radio><el-radio value="1">离职</el-radio></el-radio-group></el-form-item></el-col>
        </el-row>
        <el-form-item v-if="form.status === '1'" label="离职日期" prop="leaveDate"><el-date-picker v-model="form.leaveDate" type="date" value-format="YYYY-MM-DD" /></el-form-item>
        <p class="form-tip">档案创建后不能更换账号。员工状态与账号登录状态分别维护；离职后请在用户管理中停用账号。</p>
        <el-form-item label="备注"><el-input v-model="form.remark" type="textarea" maxlength="500" show-word-limit :rows="3" /></el-form-item>
      </el-form>
      <template #footer><el-button @click="open = false">{{ readonly ? '关闭' : '取消' }}</el-button><el-button v-if="!readonly" type="primary" :loading="saving" @click="save">保存</el-button></template>
    </el-dialog>
  </div>
</template>

<script setup name="AttendanceEmployee">
import FaceDialog from './FaceDialog.vue'
import { listEmployee, getEmployee, addEmployee, updateEmployee, deleteEmployee, userOptions } from '@/api/attendance/employee'
import { siteOptions, departmentOptions } from '@/api/attendance/site'
const { proxy } = getCurrentInstance()
const faceDialog = ref()
const rows = ref([]), total = ref(0), selected = ref([]), loading = ref(false), showSearch = ref(true)
const query = reactive({ pageNum: 1, pageSize: 10, employeeNo: '', employeeName: '', deptId: undefined, siteId: undefined, status: '' })
const departments = ref([]), sites = ref([]), users = ref([]), usersLoading = ref(false), sitesLoading = ref(false)
const form = ref({}), open = ref(false), readonly = ref(false), saving = ref(false), formRef = ref(), originalSite = ref(null)
const formSites = computed(() => originalSite.value && !sites.value.some(s => s.id === originalSite.value.id) ? [originalSite.value, ...sites.value] : sites.value)
const required = message => ({ required: true, message, trigger: 'blur' })
const rules = {
  employeeNo: [required('请输入工号'), { pattern: /^[A-Za-z0-9_-]+$/, message: '只能包含字母、数字、下划线和短横线', trigger: 'blur' }],
  employeeName: [required('请输入员工姓名')], userId: [required('请选择系统账号')], siteId: [required('请选择办公场所')], hireDate: [required('请选择入职日期')],
  phone: [{ pattern: /^[0-9+() -]*$/, message: '联系电话格式不正确', trigger: 'blur' }],
  email: [{ type: 'email', message: '邮箱格式不正确', trigger: 'blur' }],
  leaveDate: [{ validator: (_, value, cb) => cb(form.value.status === '1' && !value ? new Error('请选择离职日期') : value && value < form.value.hireDate ? new Error('离职日期不能早于入职日期') : undefined), trigger: 'change' }]
}
let userRequest = 0, siteRequest = 0
async function searchUsers(keyword = '') {
  const version = ++userRequest; usersLoading.value = true
  try { const response = await userOptions(keyword); if (version === userRequest) users.value = response.data }
  finally { if (version === userRequest) usersLoading.value = false }
}
async function searchSites(keyword = '') {
  const version = ++siteRequest; sitesLoading.value = true
  try { const response = await siteOptions(keyword); if (version === siteRequest) sites.value = response.data }
  finally { if (version === siteRequest) sitesLoading.value = false }
}
function selectUser(id) { form.value.deptName = users.value.find(u => u.id === id)?.deptName || '' }
function changeStatus(status) { if (status === '0') form.value.leaveDate = null }
function clearValidation() { formRef.value?.clearValidate() }
async function load() {
  loading.value = true
  try { const response = await listEmployee(query); rows.value = response.rows; total.value = response.total; selected.value = [] }
  finally { loading.value = false }
}
function search() { query.pageNum = 1; load() }
function resetQuery() { proxy.resetForm('queryRef'); search() }
async function openAdd() {
  await Promise.all([searchUsers(), searchSites()])
  form.value = { employeeNo: '', employeeName: '', userId: undefined, siteId: undefined, phone: '', email: '', hireDate: undefined, leaveDate: null, status: '0', remark: '' }
  originalSite.value = null; readonly.value = false; open.value = true; nextTick(clearValidation)
}
async function openEdit(row, viewOnly = false) {
  const response = await getEmployee(row.employeeId)
  if (!viewOnly) await searchSites()
  form.value = response.data
  originalSite.value = { id: form.value.siteId, label: form.value.siteName + (form.value.siteStatus === '1' ? '（已停用）' : ''), status: form.value.siteStatus }
  readonly.value = viewOnly; open.value = true; nextTick(clearValidation)
}
async function save() {
  if (!await formRef.value.validate().catch(() => false)) return
  saving.value = true
  try { await (form.value.employeeId ? updateEmployee(form.value) : addEmployee(form.value)); proxy.$modal.msgSuccess('保存成功'); open.value = false; await load() }
  finally { saving.value = false }
}
async function remove(ids) {
  if (ids.length > 100) return proxy.$modal.msgWarning('每次最多删除100条')
  try { await proxy.$modal.confirm(`确认删除这 ${ids.length} 份员工档案并解除绑定？系统账号会保留。离职员工建议保留档案并改为离职状态。`) } catch { return }
  await deleteEmployee(ids); proxy.$modal.msgSuccess('删除成功'); await load()
}
departmentOptions().then(response => departments.value = response.data)
searchSites()
load()
</script>
<style scoped>.mb16 { margin-bottom: 16px; } .form-tip { color: var(--el-text-color-secondary); font-size: 12px; margin: 0 0 18px 100px; line-height: 1.7; }</style>
