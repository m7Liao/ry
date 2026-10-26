import request from '@/utils/request'

export const listSite = params => request({ url: '/attendance/site/list', method: 'get', params })
export const getSite = id => request({ url: `/attendance/site/${id}`, method: 'get' })
export const addSite = data => request({ url: '/attendance/site', method: 'post', data })
export const updateSite = data => request({ url: '/attendance/site', method: 'put', data })
export const deleteSite = ids => request({ url: `/attendance/site/${ids}`, method: 'delete' })
export const siteOptions = keyword => request({ url: '/attendance/site/options', method: 'get', params: { keyword } })
export const departmentOptions = () => request({ url: '/attendance/site/departments', method: 'get' })
