import request from '@/utils/request'

export const listSession = params => request({ url: '/attendance/session/list', method: 'get', params })
export const getSession = id => request({ url: `/attendance/session/${id}`, method: 'get' })
export const createSession = data => request({ url: '/attendance/session', method: 'post', data })
export const closeSession = id => request({ url: `/attendance/session/${id}/close`, method: 'put' })
export const issueQrCode = id => request({ url: `/attendance/session/${id}/qrcode`, method: 'post', headers: { repeatSubmit: false } })
export const listRecord = params => request({ url: '/attendance/record/list', method: 'get', params })
export const getRecord = id => request({ url: `/attendance/record/${id}`, method: 'get' })
export const myIdentity = () => request({ url: '/attendance/checkin/me', method: 'get', quiet: true })
export const previewCheckin = ticket => request({ url: '/attendance/checkin/preview', method: 'post', data: { ticket }, quiet: true, headers: { repeatSubmit: false } })
export const submitCheckin = ticket => request({ url: '/attendance/checkin/submit', method: 'post', data: { ticket }, quiet: true, headers: { repeatSubmit: false } })
export const myRecords = params => request({ url: '/attendance/checkin/records', method: 'get', params, quiet: true })
