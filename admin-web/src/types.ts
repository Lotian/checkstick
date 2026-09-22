export type RoundStatus = 'ACTIVE' | 'FULL' | 'CLOSED'
export type RoleType = 'GROOM' | 'BRIDE' | 'VILLAGER'

/** 服务端下发的运行时配置；playerBaseUrl 为空串表示玩家端与后台同源。 */
export interface AppConfig {
  playerBaseUrl: string
}

/** 玩家扫码后首先看到的故事简介。 */
export interface StoryIntro {
  title: string
  subtitle: string
  introText: string
  warningText: string
  updatedAt?: string
}

/** 一局的人数区间：签位数量 = maxPlayers，抽满 minPlayers 后可以提前封签。 */
export interface PlayerRange {
  minPlayers: number
  maxPlayers: number
}

export interface CurrentRoundSummary extends PlayerRange {
  id: string
  roundNumber: number
  status: RoundStatus
  drawnCount: number
  startedAt: string
}

export interface GameGroup extends PlayerRange {
  id: string
  name: string
  code: string
  enabled: boolean
  createdAt: string
  currentRound: CurrentRoundSummary | null
}

export interface DrawDetail {
  slotId: string
  slotIndex: number
  roleType: RoleType
  roleName: string
  visitorId: string
  drawnAt: string
}

export interface RoundDetail extends PlayerRange {
  id: string
  groupId: string
  groupName: string
  roundNumber: number
  status: RoundStatus
  drawnCount: number
  remainingCount: number
  startedAt: string
  closedAt: string | null
  /** 已抽满最低人数，可以由工作人员提前封签。 */
  canCloseEarly: boolean
  draws: DrawDetail[]
}

export interface RoundListItem extends PlayerRange {
  id: string
  roundNumber: number
  status: RoundStatus
  drawnCount: number
  startedAt: string
  closedAt: string | null
}

/** 身份模板不再区分人数，每个身份一套。 */
export interface RoleTemplate {
  id: string
  roleType: RoleType
  roleName: string
  taskText: string
  rewardText: string
  updatedAt: string
}
