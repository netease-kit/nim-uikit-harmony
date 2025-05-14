import { ChatKitClient, ContactRepo, ErrorUtils, NEFriendUserCache, NEUserWithFriend } from '@nimkit/chatkit'
import { NECommonUtils } from '@nimkit/common'
import { V2NIMError, V2NIMFriend, V2NIMFriendAddMode, V2NIMFriendDeletionType, V2NIMUser } from '@nimsdk/base'

@ObservedV2
export class PersonInfoViewModel {
  @Trace accountId: string = ''
  @Trace userWithFriend: NEUserWithFriend | undefined = undefined
  // 【加入黑名单】开关切换事件
  onAddBlockClick = async (isOpen: boolean) => {
    if (ErrorUtils.checkNetworkAndToast()) {
      const accountId = this.userWithFriend?.user?.accountId
      if (accountId) {
        try {
          if (isOpen) {
            await ContactRepo.addUserToBlockList(accountId)
          } else {
            await ContactRepo.removeUserFromBlockList(accountId)
          }
        } catch (err) {
          console.error(err)
        }
      }
    }
  }
  // 【添加好友】按钮点击事件
  onAddFriendClick = async () => {
    if (ErrorUtils.checkNetworkAndToast()) {
      try {
        await ContactRepo.addFriend(this.accountId, {
          addMode: V2NIMFriendAddMode.V2NIM_FRIEND_MODE_TYPE_APPLY,
          postscript: ''
        })

        // 移除黑名单
        await ContactRepo.removeUserFromBlockList(this.accountId)
        NECommonUtils.showToast($r('app.string.person_info_add_tip'))
      } catch (err) {
        const error  = err as V2NIMError
        NECommonUtils.showToast(error.message)
        console.error(err)
      }
    }
  }

  async init(accountId: string) {
    this.accountId = accountId
    this.addListener()
    await this.getFriend()
  }

  onUpdateUserInfoFun = (users: V2NIMUser[]) => {
    // this.getFriend()
    if (typeof users === 'undefined' || typeof this.userWithFriend === 'undefined') {
      return // ignore
    }

    for (const user of users) {
      if (user.accountId === this.accountId) {
        this.userWithFriend = new NEUserWithFriend({
          friend: this.userWithFriend.friend,
          user: user
        })
        break;
      }
    }
  }
  onFriendAddedFun = (friend: V2NIMFriend) => {
    if (friend.accountId !== this.accountId) {
      return
    }
    this.userWithFriend = new NEUserWithFriend({
      friend: friend
    })
    // 更新 user 信息至最新
    ContactRepo.getUserListFromCloud([friend.accountId])
  }
  onFriendDeletedFun = (accountId: string, deletionType: V2NIMFriendDeletionType) => {
    if (accountId !== this.accountId) {
      return
    }
    if (this.userWithFriend?.friend) {
      this.userWithFriend.friend = undefined
    }
  }
  onFriendInfoChangedFun = (friend: V2NIMFriend) => {
    if (friend.accountId !== this.accountId) {
      return
    }
    if (this.userWithFriend?.friend) {
      this.userWithFriend.friend = friend
    }
  }

  addListener() {
    ContactRepo.listener.on('updateUserInfo', this.onUpdateUserInfoFun)
    ChatKitClient.nim.friendService?.on('onFriendAdded', this.onFriendAddedFun)
    ChatKitClient.nim.friendService?.on('onFriendDeleted', this.onFriendDeletedFun)
    ChatKitClient.nim.friendService?.on('onFriendInfoChanged', this.onFriendInfoChangedFun)
  }

  async getFriend() {
    try {
      const userWithFriends = await ContactRepo.getUserWithFriendByIds([this.accountId])
      if (userWithFriends.length > 0) {
        this.userWithFriend = userWithFriends[0]
      } else {
        this.userWithFriend = NEFriendUserCache.getInstance().getFriendById(this.accountId)
      }
    } catch (err) {
      console.error(err)
      this.userWithFriend = NEFriendUserCache.getInstance().getFriendById(this.accountId)
    }
  }

  onDestroy() {
    ContactRepo.listener.off('updateUserInfo', this.onUpdateUserInfoFun)
    ChatKitClient.nim.friendService?.off('onFriendAdded', this.onFriendAddedFun)
    ChatKitClient.nim.friendService?.off('onFriendDeleted', this.onFriendDeletedFun)
    ChatKitClient.nim.friendService?.off('onFriendInfoChanged', this.onFriendInfoChangedFun)
  }
}