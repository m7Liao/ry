import request from '@/utils/request'

export const listRule = params => request({ url: '/attendance/rule/list', method: 'get', params })
export const getRule = id => request({ url: `/attendance/rule/${id}`, method: 'get' })
export const addRule = data => request({ url: '/attendance/rule', method: 'post', data })
export const updateRule = data => request({ url: '/attendance/rule', method: 'put', data })
export const deleteRule = id => request({ url: `/attendance/rule/${id}`, method: 'delete' })
