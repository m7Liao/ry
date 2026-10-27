import assert from 'node:assert/strict'
import fs from 'node:fs'
const source = fs.readFileSync(new URL('../Vue3-master/src/components/FaceCapture/index.vue', import.meta.url), 'utf8').match(/<script setup[^>]*>([\s\S]*?)<\/script>/)[1]
function mount(getUserMedia, secure = true) {
  const events = [], revoked = [], callbacks = [], unmount = [], created = []
  const video = { videoWidth: 960, videoHeight: 720, srcObject: null, play: async () => {} }
  const setup = new Function('defineProps','defineEmits','ref','onBeforeUnmount','nextTick','window','navigator','URL','document', `${source}\nreturn {openCamera,capture,upload,stop,video,active,opening,error,preview}`)
  const component = setup(() => ({ disabled:false, allowUpload:true }), () => (...e) => events.push(e), value => ({value}), callback => unmount.push(callback), async () => {}, { isSecureContext:secure }, { mediaDevices:{getUserMedia} }, { createObjectURL: b => { created.push(b); return 'blob:test' }, revokeObjectURL:u => revoked.push(u) }, { createElement:() => ({ getContext:() => ({drawImage(){}}), toBlob:callback => callbacks.push(callback) }) })
  component.video.value = video
  return {component,events,revoked,created,callbacks,unmount:() => unmount.forEach(f => f())}
}
let calls=0
const insecure=mount(async () => { calls++; },false)
await insecure.component.openCamera()
assert.equal(calls,0); assert.match(insecure.component.error.value,/HTTPS/)
let stopped=0
const media={ getTracks:() => [{stop:() => stopped++}] }
const normal=mount(async () => media)
await normal.component.openCamera(); assert.equal(normal.component.active.value,true)
normal.component.capture(); normal.callbacks[0](new Blob(['photo'],{type:'image/jpeg'}))
assert.equal(stopped,1); assert.equal(normal.component.active.value,false)
assert.equal(normal.events.at(-1)[1].type,'image/jpeg')
normal.unmount(); assert.deepEqual(normal.revoked,['blob:test'])
let grant
const pending=mount(() => new Promise(resolve => grant=resolve))
const opening=pending.component.openCamera(); pending.unmount(); grant(media); await opening
assert.equal(stopped,2); assert.equal(pending.component.active.value,false)
const late=mount(async () => media)
await late.component.openCamera(); late.component.capture(); late.unmount(); late.callbacks[0](new Blob(['late']))
assert.equal(late.created.length,0); assert.equal(late.events.length,1)
const denied=mount(async () => { throw new Error('NotAllowedError') })
await denied.component.openCamera(); assert.equal(denied.component.active.value,false); assert.match(denied.component.error.value,/权限/)
console.log('PASS: camera secure-context check, capture, track cleanup, late permission/blob callbacks and denial handling')
