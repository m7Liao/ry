import request from '@/utils/request'

export const listEmployee = params => request({ url: '/attendance/employee/list', method: 'get', params })
export const getEmployee = id => request({ url: `/attendance/employee/${id}`, method: 'get' })
export const addEmployee = data => request({ url: '/attendance/employee', method: 'post', data })
export const updateEmployee = data => request({ url: '/attendance/employee', method: 'put', data })
export const deleteEmployee = ids => request({ url: `/attendance/employee/${ids}`, method: 'delete' })
export const userOptions = keyword => request({ url: '/attendance/employee/users', method: 'get', params: { keyword } })
