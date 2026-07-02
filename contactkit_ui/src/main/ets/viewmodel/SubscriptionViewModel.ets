import { SubscriptionRepo } from "@nimkit/chatkit"

/**
 * SubscriptionViewModel
 * NIM-WS-TS
 *
 * @author hongru
 * @since 2025−06-16
 *
 * Copyright © 2025 Netease. All rights reserved.
 */
@ObservedV2
export class SubscriptionViewModel {
  @Trace onlineState: boolean = false

  getOnlineState(accountId?: string): boolean | undefined {
    return SubscriptionRepo.getOnlineState(accountId)
  }

  hasReachedSubscriptionLimit(limit?: number): boolean {
    return SubscriptionRepo.hasReachedSubscriptionLimit(limit)
  }

  async subscribeUserStatusBatch(accountIds: string[]): Promise<void> {
    await SubscriptionRepo.subscribeUserStatusBatch(accountIds)
  }

  async unsubscribeUserStatus(accountIds: string[]){
    await SubscriptionRepo.unsubscribeUserStatus(accountIds)
  }
}
