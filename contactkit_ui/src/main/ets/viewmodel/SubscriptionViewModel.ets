import { ChatKitClient, SubscriptionRepo } from "@nimkit/chatkit"
import { V2NIMUserStatus } from "@nimsdk/base"

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
  @Trace onlineStateMap: Map<string, boolean> = SubscriptionRepo.onlineStateMap

  async subscribeUserStatus(accountId: string){
    await SubscriptionRepo.subscribeUserStatus(accountId)
  }

  async unsubscribeUserStatus(accountIds: string[]){
    await SubscriptionRepo.unsubscribeUserStatus(accountIds)
  }
}