import request from '@/utils/request'

export const listDaily = params => request({ url: '/attendance/daily/list', method: 'get', params })
export const getDaily = id => request({ url: `/attendance/daily/${id}`, method: 'get' })
export const calculateDaily = data => request({ url: '/attendance/daily/calculate', method: 'post', data, timeout: 60000, headers: { repeatSubmit: false } })
export const recalculateDaily = resultIds => request({ url: '/attendance/daily/recalculate', method: 'post', data: { resultIds }, timeout: 60000, headers: { repeatSubmit: false } })
