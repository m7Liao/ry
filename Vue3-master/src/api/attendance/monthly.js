import request from '@/utils/request'
export const listMonthly = params => request({ url: '/attendance/monthly/list', method: 'get', params })
export const myMonthly = month => request({ url: '/attendance/checkin/monthly', method: 'get', params: { month } })

