<template>
  <el-dialog v-model="open" :title="`员工人脸档案 · ${employee?.employeeName || ''}`" width="min(620px,94vw)" append-to-body :close-on-click-modal="false" @closed="reset">
    <div v-loading="loading">
      <el-alert v-if="status" :type="status.ready ? 'success' : 'warning'" :title="status.message" :closable="false" />
      <p>{{ status?.enrolled ? `已录入人脸，档案版本 ${status.version}` : '尚未录入人脸' }}</p>
      <p class="face-note">只保存加密特征，原图不落盘。录入或替换前请向员工说明用途并取得同意。技术由虹软®提供。</p>
      <template v-if="canEnroll && status?.ready"><FaceCapture v-if="open" :disabled="saving" allow-upload @captured="image = $event" /><el-checkbox v-model="consent" :disabled="saving">已向员工说明用途并取得本次采集同意</el-checkbox></template>
    </div>
    <template #footer><el-button @click="open=false" :disabled="saving">关闭</el-button><el-button v-if="canRemove && status?.enrolled" type="danger" plain :disabled="saving" @click="remove">撤销人脸</el-button><el-button v-if="canEnroll" type="primary" :loading="saving" :disabled="!image || !consent || !status?.ready" @click="save">{{ status?.enrolled ? '替换人脸' : '保存人脸' }}</el-button></template>
  </el-dialog>
</template>
<script setup>
import FaceCapture from '@/components/FaceCapture/index.vue'
import { faceStatus, enrollFace, removeFace } from '@/api/attendance/face'
import { checkPermi } from '@/utils/permission'
const { proxy } = getCurrentInstance()
const open = ref(false), employee = ref(null), status = ref(null), image = ref(null), consent = ref(false), loading = ref(false), saving = ref(false)
const canEnroll = computed(() => checkPermi(['attendance:face:enroll'])), canRemove = computed(() => checkPermi(['attendance:face:remove']))
let version = 0
function reset() { version++; status.value=null; image.value=null; consent.value=false }
async function show(row) {
  reset(); employee.value=row; open.value=true; loading.value=true; const current=version
  try { const r=await faceStatus(row.employeeId); if (version===current) status.value=r.data }
  finally { if (version===current) loading.value=false }
}
async function save() {
  if (!image.value || !consent.value) return
  if (status.value?.enrolled) { try { await proxy.$modal.confirm('确认替换该员工已有人脸档案？后续签到将使用新特征。') } catch { return } }
  saving.value=true
  try { await enrollFace(employee.value.employeeId,image.value,consent.value); proxy.$modal.msgSuccess('人脸录入成功'); open.value=false }
  finally { saving.value=false }
}
async function remove() {
  try { await proxy.$modal.confirm('确认撤销该员工人脸？启用人脸核验时，该员工需重新录入后才能签到。') } catch { return }
  saving.value=true
  try { await removeFace(employee.value.employeeId); status.value={...status.value,enrolled:false}; proxy.$modal.msgSuccess('人脸已撤销') }
  finally { saving.value=false }
}
defineExpose({ show })
</script>
<style scoped>.face-note { font-size:13px; color:var(--el-text-color-secondary); line-height:1.8; }</style>
