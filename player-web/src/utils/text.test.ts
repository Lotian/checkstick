import { describe, expect, it } from 'vitest'
import { isBrandTitle, taskSteps } from './text'

describe('taskSteps', () => {
  it('兼容不同换行并忽略空步骤', () => {
    expect(taskSteps('第一步\r\n\r\n 第二步 \n第三步')).toEqual(['第一步', '第二步', '第三步'])
  })
})

describe('isBrandTitle（首屏大标题是否用毛笔字 logo）', () => {
  it('标题就是本次活动名时用 logo', () => {
    expect(isBrandTitle('纸嫁衣')).toBe(true)
    expect(isBrandTitle('  纸嫁衣  ')).toBe(true)
  })

  it('后台改成别的名字时退回普通文字，避免图文不符', () => {
    expect(isBrandTitle('囍签')).toBe(false)
    expect(isBrandTitle('纸嫁衣 · 惊奇屋')).toBe(false)
    expect(isBrandTitle('')).toBe(false)
    expect(isBrandTitle('   ')).toBe(false)
    expect(isBrandTitle(null)).toBe(false)
    expect(isBrandTitle(undefined)).toBe(false)
  })
})
