export type RoundStatus = 'ACTIVE' | 'FULL' | 'CLOSED'
export type RoleType = 'GROOM' | 'BRIDE' | 'VILLAGER'

export interface DrawResult {
  roundId: string
  roleType: RoleType
  roleName: string
  taskText: string
  rewardText: string
  drawnAt: string
}

/** 管理端动态维护的扫码首屏故事内容。 */
export interface StoryIntro {
  title: string
  subtitle: string
  introText: string
  warningText: string
  updatedAt?: string
}

/** 一局的人数区间：签位数量 = maxPlayers，抽满 minPlayers 后可提前封签。 */
export interface PublicGroupState {
  groupId: string
  groupName: string
  groupCode: string
  roundId: string | null
  roundNumber: number | null
  minPlayers: number | null
  maxPlayers: number | null
  roundStatus: RoundStatus | null
  drawnCount: number
  remainingCount: number
  result: DrawResult | null
}
