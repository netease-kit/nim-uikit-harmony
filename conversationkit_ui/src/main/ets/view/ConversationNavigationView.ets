import { Logger } from '@nimkit/common';
import { ChatKitClient, ErrorUtils, NEUserWithFriend, IMKitConfigCenter, PersonSelectParam, TeamRepo } from '@nimkit/chatkit'
import { NECommonUtils } from '@nimkit/common'
import { scanBarcode, scanCore } from '@kit.ScanKit'
import { V2NIMUserAIBot } from '@nimsdk/base'
import {
  ConversationOpenIntent,
  ConversationOpenSource,
  ConversationRouteKey,
  ConversationRouteKind
} from '../model/ConversationOpenIntent'

@ComponentV2
export struct ConversationNavigationView {
  @Local conversationPopupShowed: boolean = false
  @Param pathStack: NavPathStack = new NavPathStack()
  @Param onOpenConversation?: (intent: ConversationOpenIntent) => void = undefined
  @Param onOpenDetail?: (info: NavPathInfo) => void = undefined
  @Event goSearchPage: (pathStack: NavPathStack) => void = (pathStack: NavPathStack) => {
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Image($r('app.media.brand'))
          .margin({ left: 20 })
          .width(32)
          .height(32)
          .objectFit(ImageFit.Contain)
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
            this.goSearchPage(this.pathStack)
          })

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
          .bindPopup(this.conversationPopupShowed, {
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
        .backgroundColor('#E9EFF5')
    }
    .height('100%')
    .width('100%')
  }

  @Builder
  popupBuilder() {
    Column({ space: 16 }) {
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
          this.goAddFriend()
        }
      })

      if (IMKitConfigCenter.enableTeam) {
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
            this.goToPersonSelectPage(true)
          }
        })

        Row() {
          Image($r('app.media.team_advance'))
            .width(14)
            .height(14)
          Text($r('app.string.create_advance_team'))
            .fontSize(14)
            .fontColor('#ff333333')
            .margin({ left: 6 })
        }.onClick(() => {
          if (this.conversationPopupShowed) {
            this.conversationPopupShowed = false
            this.goToPersonSelectPage(false)
          }
        })

        Row() {
          Image($r('app.media.team_join'))
            .width(14)
            .height(14)
          Text($r('app.string.join_team'))
            .fontSize(14)
            .fontColor('#ff333333')
            .margin({ left: 6 })
        }.onClick(() => {
          if (this.conversationPopupShowed) {
            this.conversationPopupShowed = false
            this.goSearchTeam()
          }
        })

        Row() {
          Image($r('app.media.nav_scan'))
            .width(14)
            .height(14)
          Text($r('app.string.bot_scan_entry'))
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
      let qrcode = ''
      let expireAt: number = 0
      try {
        const parsed = JSON.parse(rawValue) as Record<string, string | number>
        qrcode = (parsed['qrCode'] as string) ?? ''
        expireAt = (parsed['expireAt'] as number) ?? 0
      } catch {
        NECommonUtils.showToast($r('app.string.bot_scan_invalid_qr'))
        return
      }
      if (qrcode.length <= 0) {
        NECommonUtils.showToast($r('app.string.bot_scan_invalid_qr'))
        return
      }
      if (!ErrorUtils.checkNetworkAndToast()) {
        return
      }
      if (expireAt > 0 && Date.now() > expireAt) {
        AlertDialog.show({
          title: $r('app.string.bot_qr_expired_title'),
          message: $r('app.string.bot_qr_expired_message'),
          autoCancel: true,
          buttons: [{
            value: $r('app.string.bot_qr_expired_btn'),
            fontColor: '#337EFF',
            action: () => {
            }
          }]
        })
        return
      }
      this.openDetail({
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
      Logger.error('ConversationKit', '[ConversationNavigationView] scan error: ' + JSON.stringify(scanErr))
    }
  }

  goSearchTeam() {
    this.openDetail({ name: 'SearchTeamPage' })
  }

  goAddFriend() {
    this.openDetail({ name: 'AddFriendPage' })
  }

  groupSelectorCallback = async (selectedList: NEUserWithFriend[]) => {
    try {
      this.pathStack.pop()
      let invitees = selectedList.map(user => user.user?.accountId ?? '')
      this.createGroupTeam(invitees)
    } catch (err) {
      Logger.info('ConversationKit', err)
    }
  }

  teamSelectorCallback = async (selectedList: NEUserWithFriend[]) => {
    try {
      this.pathStack.pop()
      let invitees = selectedList.map(user => user.user?.accountId ?? '')
      this.createAdvanceTeam(invitees)
    } catch (err) {
      Logger.info('ConversationKit', err)
    }
  }

  goToPersonSelectPage(isGroup: boolean) {
    if (isGroup) {
      this.openDetail({
        name: 'PersonSelectPage',
        param: new PersonSelectParam(this.groupSelectorCallback, [], 200, true)
      })
    } else {
      this.openDetail({
        name: 'PersonSelectPage',
        param: new PersonSelectParam(this.teamSelectorCallback, [], 200, true)
      })
    }
  }

  createGroupTeam(invitees: string[]) {
    TeamRepo.createGroupTeam(invitees).then((result) => {
      if (result) {
        this.openTeamConversation(result.team.teamId)
      }
    })
  }

  createAdvanceTeam(invitees: string[]) {
    TeamRepo.createAdvanceTeam(invitees).then((result) => {
      if (result) {
        this.openTeamConversation(result.team.teamId)
      }
    })
  }

  private openDetail(info: NavPathInfo): void {
    if (this.onOpenDetail) {
      this.onOpenDetail(info)
      return
    }
    this.pathStack.pushPath(info)
  }

  private openTeamConversation(teamId: string): void {
    const conversationId = ChatKitClient.nim.conversationIdUtil.teamConversationId(teamId)
    const intent = new ConversationOpenIntent(
      new ConversationRouteKey(ConversationRouteKind.TEAM, conversationId),
      ConversationOpenSource.CONVERSATION_LIST
    )
    if (this.onOpenConversation) {
      this.onOpenConversation(intent)
      return
    }
    this.pathStack.pushPath({ name: 'ChatTeamPage', param: conversationId })
  }
}
