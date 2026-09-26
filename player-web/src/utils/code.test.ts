import { describe, expect, it } from 'vitest'
import { isCompleteGroupCode, normalizeGroupCode, resolveStoredGroupCode } from './code'

describe('normalizeGroupCode（输入框实时清洗）', () => {
  it('纯数字输入：去空白并最多保留前 4 位', () => {
    expect(normalizeGroupCode('1024')).toBe('1024')
    expect(normalizeGroupCode('  1024  ')).toBe('1024')
    expect(normalizeGroupCode('102499')).toBe('1024')
    expect(normalizeGroupCode('0')).toBe('0')
    expect(normalizeGroupCode('0123')).toBe('0123')
  })

  it('含非数字的输入整体作废，不从中抠数字', () => {
    // 这一条是线上 bug 的回归用例：旧版 6 位码 RR98DN 曾被抠成 "98" 显示在输入框里
    expect(normalizeGroupCode('RR98DN')).toBe('')
    expect(normalizeGroupCode('1a0b2c4')).toBe('')
    expect(normalizeGroupCode('组局码1024')).toBe('')
  })

  it('空值安全', () => {
    expect(normalizeGroupCode('')).toBe('')
    expect(normalizeGroupCode('   ')).toBe('')
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

describe('resolveStoredGroupCode（localStorage 历史值迁移）', () => {
  it('沿用本来就是 4 位数字的历史值', () => {
    expect(resolveStoredGroupCode('1024')).toBe('1024')
    expect(resolveStoredGroupCode('  1024  ')).toBe('1024')
    expect(resolveStoredGroupCode('0000')).toBe('0000')
  })

  it('丢弃旧版 6 位码与残缺值，避免显示半截数字', () => {
    expect(resolveStoredGroupCode('RR98DN')).toBe('')
    expect(resolveStoredGroupCode('98')).toBe('')
    expect(resolveStoredGroupCode('10245')).toBe('')
    expect(resolveStoredGroupCode('')).toBe('')
    expect(resolveStoredGroupCode(null)).toBe('')
    expect(resolveStoredGroupCode(undefined)).toBe('')
  })
})
