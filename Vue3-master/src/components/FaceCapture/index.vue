<template>
  <div class="face-capture">
    <video v-show="active" ref="video" autoplay playsinline muted aria-label="人脸采集摄像头预览" />
    <img v-if="preview && !active" :src="preview" alt="本次人脸采集照片" />
    <p v-if="error" class="capture-error" role="alert">{{ error }}</p>
    <div class="capture-actions">
      <el-button :disabled="disabled || opening" @click="openCamera">{{ opening ? '正在打开' : active ? '重新打开摄像头' : '打开摄像头' }}</el-button>
      <el-button v-if="active" :disabled="disabled" type="primary" @click="capture">拍照</el-button>
      <el-button v-if="active" :disabled="disabled" @click="stop">关闭摄像头</el-button>
      <label v-if="allowUpload" class="upload-label"><span>选择照片</span><input type="file" accept="image/jpeg,image/png" :disabled="disabled" @change="upload" /></label>
    </div>
    <p class="capture-hint">请正对镜头，确保画面中仅有本人。采集用于人脸比对，不代表已完成活体检测。摄像头需使用HTTPS或本机localhost安全环境。</p>
  </div>
</template>
<script setup name="FaceCapture">
const props = defineProps({ disabled: Boolean, allowUpload: Boolean })
const emit = defineEmits(['captured'])
const video = ref(), active = ref(false), opening = ref(false), preview = ref(''), error = ref('')
let stream, sequence = 0
function stop() { sequence++; if (stream) stream.getTracks().forEach(track => track.stop()); stream = null; active.value = false; if (video.value) video.value.srcObject = null }
function clearPreview() { if (preview.value) URL.revokeObjectURL(preview.value); preview.value = '' }
function choose(blob) { clearPreview(); preview.value = URL.createObjectURL(blob); emit('captured', blob) }
async function openCamera() {
  if (props.disabled) return
  stop(); clearPreview(); emit('captured', null); error.value = ''
  if (!window.isSecureContext || !navigator.mediaDevices?.getUserMedia) { error.value = '浏览器未提供摄像头，请使用HTTPS或localhost并允许摄像头权限'; return }
  opening.value = true; const current = sequence
  try {
    const media = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'user', width: { ideal: 960 }, height: { ideal: 720 } }, audio: false })
    if (current !== sequence) { media.getTracks().forEach(t => t.stop()); return }
    stream = media; active.value = true; await nextTick(); video.value.srcObject = media; await video.value.play()
  } catch (e) { if (current === sequence) { stop(); error.value = '无法打开摄像头，请检查权限和设备占用情况' } }
  finally { opening.value = false }
}
function capture() {
  const el = video.value
  if (!el?.videoWidth || !el.videoHeight) { error.value = '摄像头画面尚未就绪'; return }
  const canvas = document.createElement('canvas'), scale = Math.min(1, 1280 / Math.max(el.videoWidth, el.videoHeight))
  canvas.width = Math.floor(el.videoWidth * scale); canvas.height = Math.floor(el.videoHeight * scale)
  canvas.getContext('2d').drawImage(el, 0, 0, canvas.width, canvas.height)
  const current = sequence
  canvas.toBlob(blob => { if (current !== sequence) return; if (blob) { choose(blob); stop() } else error.value = '拍照失败，请重试' }, 'image/jpeg', 0.9)
}
function upload(event) {
  const file = event.target.files?.[0]; event.target.value = ''; error.value = ''
  if (!file) return
  if (!['image/jpeg', 'image/png'].includes(file.type) || file.size > 4 * 1024 * 1024) { error.value = '请选择不超过4MB的JPEG或PNG'; return }
  stop(); choose(file)
}
onBeforeUnmount(() => { stop(); clearPreview() })
</script>
<style scoped>
.face-capture video,.face-capture img { display:block; max-width:100%; width:420px; max-height:360px; object-fit:contain; background:#172333; border-radius:8px; margin-bottom:12px; }
.capture-actions { display:flex; gap:8px; flex-wrap:wrap; align-items:center; } .capture-actions :deep(.el-button+.el-button) { margin-left:0; }
.capture-error { color:#c0392b; } .capture-hint { font-size:12px; line-height:1.7; color:#606b7b; } .upload-label { position:relative; color:#409eff; cursor:pointer; padding:8px; } .upload-label input { position:absolute; inset:0; opacity:0; width:100%; cursor:pointer; }
</style>
