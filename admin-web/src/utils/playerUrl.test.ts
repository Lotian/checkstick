import { describe, expect, it } from 'vitest'
import { resolvePlayerBaseUrl } from './playerUrl'

describe('resolvePlayerBaseUrl', () => {
  it('未配置时回退到与后台同源', () => {
    expect(resolvePlayerBaseUrl('', 'https://admin.example.com')).toBe('https://admin.example.com/')
    expect(resolvePlayerBaseUrl(undefined, 'https://admin.example.com')).toBe('https://admin.example.com/')
    expect(resolvePlayerBaseUrl('   ', 'https://admin.example.com')).toBe('https://admin.example.com/')
  })

  it('配置了独立玩家域名时原样使用并补齐结尾斜杠', () => {
    expect(resolvePlayerBaseUrl('https://h5.example.com', 'https://admin.example.com')).toBe('https://h5.example.com/')
    expect(resolvePlayerBaseUrl('https://h5.example.com/', 'https://admin.example.com')).toBe('https://h5.example.com/')
    expect(resolvePlayerBaseUrl('  https://h5.example.com  ', 'https://admin.example.com')).toBe('https://h5.example.com/')
  })

  it('兼容带端口与子路径的地址', () => {
    expect(resolvePlayerBaseUrl('http://192.168.1.10:8081', 'http://192.168.1.10:5174')).toBe('http://192.168.1.10:8081/')
    expect(resolvePlayerBaseUrl('https://example.com/h5', 'https://example.com/admin')).toBe('https://example.com/h5/')
  })
})
