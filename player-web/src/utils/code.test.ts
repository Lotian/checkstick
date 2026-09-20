import { describe, expect, it } from 'vitest'
import { isCompleteGroupCode, normalizeGroupCode } from './code'

describe('normalizeGroupCode', () => {
  it('保留数字并截断到 4 位', () => {
    expect(normalizeGroupCode('1024')).toBe('1024')
    expect(normalizeGroupCode('  1024  ')).toBe('1024')
    expect(normalizeGroupCode('102499')).toBe('1024')
    expect(normalizeGroupCode('1a0b2c4')).toBe('1024')
  })

  it('清掉旧版 6 位字母数字组局码', () => {
    expect(normalizeGroupCode('RR98DN')).toBe('98')
    expect(normalizeGroupCode('')).toBe('')
    expect(normalizeGroupCode(null)).toBe('')
    expect(normalizeGroupCode(undefined)).toBe('')
  })
})

describe('isCompleteGroupCode', () => {
  it('只有 4 位数字才算完整', () => {
    expect(isCompleteGroupCode('0000')).toBe(true)
    expect(isCompleteGroupCode('0123')).toBe(true)
    expect(isCompleteGroupCode(' 1024 ')).toBe(true)
    expect(isCompleteGroupCode('102')).toBe(false)
    expect(isCompleteGroupCode('10245')).toBe(false)
    expect(isCompleteGroupCode('RR98DN')).toBe(false)
    expect(isCompleteGroupCode('')).toBe(false)
  })
})
