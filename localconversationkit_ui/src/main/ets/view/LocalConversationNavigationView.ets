import { ChatKitClient, ChatRepo, ErrorUtils, NEUserWithFriend, PersonSelectParam, TeamRepo } from '@nimkit/chatkit'
import { NECommonUtils } from '@nimkit/common'
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { V2NIMUserAIBot } from '@nimsdk/base';

/**
 * LocalConversationNavigationView
 * NIM-WS-TS
 *
 * @author hongru
 * @since 2025−06-03
 *
 * Copyright © 2025 Netease. All rights reserved.
 */
@ComponentV2
export struct LocalConversationNavigationView {
  @Local conversationPopupShowed: boolean = false
  @Param pathStack: NavPathStack = new NavPathStack()
  @Event goSearchPage: (pathStack: NavPathStack) => void = (pathStack: NavPathStack) => {
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        //标题栏左侧图标
        Image($r('app.media.brand'))
          .margin({ left: 20 })
          .width(32)
          .height(32)
          .objectFit(ImageFit.Contain)
        //标题栏左侧文字
        Text($r('app.string.conversation_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .height(32)
          .width('100%')
          .margin({ left: 12, right: 12 })
          .layoutWeight(2)
          .textAlign(TextAlign.Start)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row()
          .height(1)
          .layoutWeight(1)

        //标题栏右侧搜索图标
        Image($r('app.media.nav_search'))
          .width(32)
          .height(32)
          .padding({
            left: 3,
            right: 3,
            top: 3,
            bottom: 3
          })
          .margin({ right: 10 })
          .onClick(() => {
            //点击去搜索
            this.goSearchPage(this.pathStack)
          })

        //标题栏右侧更多按钮图标
        Image($r('app.media.nav_add'))
          .width(32)
          .height(32)
          .padding({
            left: 3,
            right: 3,
            top: 3,
            bottom: 3
          })
          .margin({ right: 20 })
          .onClick(() => {
            this.conversationPopupShowed = !this.conversationPopupShowed
          })
          .bindPopup(this.conversationPopupShowed,
            //右侧更多操作弹框
            {
              targetSpace: 'popupLocation',
              builder: this.popupBuilder,
              placement: Placement.Bottom,
              mask: true,
              popupColor: Color.White,
              enableArrow: false,
              showInSubWindow: false,
              autoCancel: true,
              onStateChange: (e) => {
                if (!e.isVisible) {
                  this.conversationPopupShowed = false
                }
              }
            })

      }
      .height(55)
      .alignSelf(ItemAlign.Start)

      Row()
        .width('100%')
        .height(1)
        .backgroundColor("#E9EFF5")
    }
    .height('100%')
    .width('100%')
  }

  @Builder
  popupBuilder() {
    Column({ space: 16 }) {
      //添加好友
      Row() {
        Image($r('app.media.friend_add'))
          .width(14)
          .height(14)
        Text($r('app.string.add_friend'))
          .fontSize(14)
          .fontColor('#ff333333')
          .margin({ left: 6 })
      }.onClick(() => {
        if (this.conversationPopupShowed) {
          this.conversationPopupShowed = false
          this.goAddFriend(this.pathStack)
        }
      })

      //创建讨论组
      Row() {
        Image($r('app.media.team_discuss'))
          .width(14)
          .height(14)
        Text($r('app.string.create_discuss_team'))
          .fontSize(14)
          .fontColor('#ff333333')
          .margin({ left: 6 })
      }.onClick(() => {
        if (this.conversationPopupShowed) {
          this.conversationPopupShowed = false
          this.goToPersonSelectPage(this.pathStack, true)
        }
      })

      //创建高级群
      Row() {
        Image($r("app.media.team_advance"))
          .width(14)
          .height(14)
        Text($r('app.string.create_advance_team'))
          .fontSize(14)
          .fontColor('#ff333333')
          .margin({ left: 6 })
      }.onClick(() => {
        if (this.conversationPopupShowed) {
          this.conversationPopupShowed = false
          this.goToPersonSelectPage(this.pathStack, false)
        }
      })

      //扫一扫
      Row() {
        Image($r('app.media.nav_scan'))
          .width(14)
          .height(14)
        Text('扫一扫')
          .fontSize(14)
          .fontColor('#ff333333')
          .margin({ left: 6 })
      }.onClick(() => {
        if (this.conversationPopupShowed) {
          this.conversationPopupShowed = false
          this.doScan()
        }
      })
    }
    .width(122)
    .padding({
      top: 16,
      left: 16,
      bottom: 16
    })
    .alignItems(HorizontalAlign.Start)
    .borderRadius(8)
    .backgroundColor('#ffFFFFFF')
  }

  private async doScan(): Promise<void> {
    try {
      const result = await scanBarcode.startScanForResult(getContext(this), {
        scanTypes: [scanCore.ScanType.ALL]
      })
      const rawValue = result.originalValue ?? ''
      // 解析二维码内容：JSON 格式优先
      let qrcode = ''
      let expireAt: number = 0
      try {
        const parsed = JSON.parse(rawValue) as Record<string, string | number>
        qrcode = (parsed['qrCode'] as string) ?? ''
        expireAt = (parsed['expireAt'] as number) ?? 0
      } catch {
        // 非 JSON 格式的二维码不是合法的 Bot 二维码
        NECommonUtils.showToast($r('app.string.bot_scan_invalid_qr'))
        return
      }
      if (qrcode.length <= 0) {
        NECommonUtils.showToast($r('app.string.bot_scan_invalid_qr'))
        return
      }
      // 先判网络，无网络不做过期校验
      if (!ErrorUtils.checkNetworkAndToast()) return
      // 过期校验
      if (expireAt > 0 && Date.now() > expireAt) {
        AlertDialog.show({
          title: $r('app.string.bot_qr_expired_title'),
          message: $r('app.string.bot_qr_expired_message'),
          autoCancel: true,
          buttons: [{
            value: $r('app.string.bot_qr_expired_btn'),
            fontColor: '#337EFF',
            action: () => {}
          }]
        })
        return
      }
      this.pathStack.pushPath({
        name: 'BindBotPage',
        param: qrcode,
        onPop: (popInfo: PopInfo) => {
          const bot = popInfo.result as V2NIMUserAIBot | undefined
          if (bot && bot.accid) {
            this.pathStack.pushPath({ name: 'BotInfoPage', param: bot })
          }
        }
      })
    } catch (scanErr) {
      console.error('[LocalConversation] scan error: ' + JSON.stringify(scanErr))
    }
  }

  ///**
  // * 搜索页面
  // */
  //goSearchPage(pathStack: NavPathStack) {
  //  pathStack.pushPath({ name: "SearchPage" })
  //}

  /**
   * 添加好友
   */
  goAddFriend(pathStack: NavPathStack) {
    pathStack.pushPath({ name: "AddFriendPage" })
  }

  // 创建讨论组的人选选择器返回
  groupSelectorCallback = async (selectedList: NEUserWithFriend[]) => {
    try {
      this.pathStack.pop()
      let invitees = selectedList.map(user => user.user?.accountId ?? '')
      this.createGroupTeam(invitees)
    } catch (err) {
      console.log(err)
    }
  }
  // 创建高级群的人选选择器返回
  teamSelectorCallback = async (selectedList: NEUserWithFriend[]) => {
    try {
      this.pathStack.pop()
      let invitees = selectedList.map(user => user.user?.accountId ?? '')
      this.createAdvanceTeam(invitees)
    } catch (err) {
      console.log(err)
    }
  }

  /**
   * 跳转到人员选择器
   * @param pathStack
   * @param isGroup
   */
  goToPersonSelectPage(pathStack: NavPathStack, isGroup: boolean) {
    if (isGroup) {
      pathStack.pushPath({
        name: "PersonSelectPage",
        param: new PersonSelectParam(this.groupSelectorCallback)
      })
    } else {
      pathStack.pushPath({
        name: "PersonSelectPage",
        param: new PersonSelectParam(this.teamSelectorCallback)
      })
    }

  }

  /**
   * 创建讨论组
   */
  createGroupTeam(invitees: string[]) {
    TeamRepo.createGroupTeam(invitees).then((result) => {
      if (result) {
        // 跳转到聊天页面
        this.pathStack.pushPath({
          name: "ChatTeamPage",
          param: ChatKitClient.nim.conversationIdUtil.teamConversationId(result.team.teamId)
        })
      }
    })
  }

  /**
   * 创建高级群
   */
  createAdvanceTeam(invitees: string[]) {
    TeamRepo.createAdvanceTeam(invitees).then((result) => {
      if (result) {
        //1，本地保存一条消息
        let message = ChatKitClient.nim.messageCreator.createTipsMessage(
          getContext(this).resourceManager.getStringSync($r('app.string.createAdvancedTeamSuccess'))
        )
        ChatRepo.saveLocalMessage(message,
          ChatKitClient.nim.conversationIdUtil.teamConversationId(result.team.teamId),
          ChatKitClient.getLoginUserId(),
          (new Date()).valueOf() - 500
        )
        // 2 跳转到聊天页面
        this.pathStack.pushPath({
          name: "ChatTeamPage",
          param: ChatKitClient.nim.conversationIdUtil.teamConversationId(result.team.teamId)
        })
      }
    })

  }
}