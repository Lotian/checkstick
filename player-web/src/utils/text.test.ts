import { describe, expect, it } from 'vitest'
import { taskSteps } from './text'

describe('taskSteps', () => {
  it('兼容不同换行并忽略空步骤', () => {
    expect(taskSteps('第一步\r\n\r\n 第二步 \n第三步')).toEqual(['第一步', '第二步', '第三步'])
  })
})
