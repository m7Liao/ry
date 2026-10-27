import request from '@/utils/request'
export const faceStatus = id => request({ url: `/attendance/face/${id}`, method: 'get', timeout: 30000 })
export const removeFace = id => request({ url: `/attendance/face/${id}`, method: 'delete' })
export const faceVerification = id => request({ url: `/attendance/face/record/${id}`, method: 'get' })
export const myFaceStatus = () => request({ url: '/attendance/checkin/face-status', method: 'get', quiet: true, timeout: 30000 })
export function enrollFace(id, image, consent) {
  const data = new FormData(); data.append('image', image, 'face.jpg'); data.append('consent', String(consent))
  return request({ url: `/attendance/face/${id}`, method: 'post', data, timeout: 30000, headers: { 'Content-Type': 'multipart/form-data', repeatSubmit: false } })
}
export function submitFaceCheckin(ticket, image) {
  const data = new FormData(); data.append('image', image, 'face.jpg'); data.append('ticket', ticket)
  return request({ url: '/attendance/checkin/face-submit', method: 'post', data, timeout: 30000, quiet: true, headers: { 'Content-Type': 'multipart/form-data', repeatSubmit: false } })
}
