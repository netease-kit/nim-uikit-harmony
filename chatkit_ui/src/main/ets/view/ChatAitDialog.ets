/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import {
  AIUserManager,
  ChatKitClient,
  keyExtensionAtAll,
  TeamMemberCache,
  TeamMemberWithUser,
  TeamRepo,
  typeExtensionAllowAll
} from '@nimkit/chatkit'
import { AvatarColorUntil, AvatarItem, CommonAvatar } from '@nimkit/common'
import { V2NIMAIUser, V2NIMTeam, V2NIMTeamMemberRole } from '@nimsdk/base'
import { NavigationDialog } from './NavigationDialog'

/**
 * @弹窗
 */
@CustomDialog
export struct ChatAitDialog {
  animationDur: number = 300
  controller: CustomDialogController
  teamId?: string
  team?: V2NIMTeam
  onMemberSelected?: (member: TeamMemberWithUser) => void
  onSelectedAll?: () => void
  onAIUserSelected?: (aiUser: V2NIMAIUser) => void
  showAitAll: boolean = true
  showAIUser: boolean = false
  showTeamMember: boolean = true
  aiUsers: V2NIMAIUser[] = []
  teamMemberCache: TeamMemberCache = TeamMemberCache.getInstance()
  @State showFlag: Visibility = Visibility.Visible
  //是否显示@All
  @State showAll: boolean = false

  build() {
    NavigationDialog() {
      Column() {
        RelativeContainer() {
          Image($r('sys.media.ohos_ic_public_arrow_down'))
            .fillColor('#999999')
            .width(16)
            .height(16)
            .margin({
              left: 20
            })
            .alignRules({
              left: { anchor: "__container__", align: HorizontalAlign.Start },
              center: { anchor: "__container__", align: VerticalAlign.Center },
            })
            .onClick(() => {
              this.closeDialog()
            })

          Text($r('app.string.chat_message_ait_select_tips'))
            .fontSize(16)
            .fontColor('#ff333333')
            .alignRules({
              middle: { anchor: "__container__", align: HorizontalAlign.Center },
              center: { anchor: "__container__", align: VerticalAlign.Center },
            })
        }.height(42)

        List() {
          if (this.showAll) {
            ListItem() {
              Row() {
                Stack() {
                  Image($r('app.media.ic_member_all'))
                    .width(24)
                    .height(24)
                }
                .borderRadius(20)
                .backgroundColor('#337EFF')
                .width(42)
                .height(42)
                .margin({
                  right: 14
                })

                Text($r('app.string.chat_team_ait_all'))
                  .fontColor('#ff333333')
                  .fontSize(16)
                  .width('70%')


              }
              .padding({
                left: 20,
                right: 20,
                top: 10,
                bottom: 10
              })
              .onClick(() => {
                this.closeDialog()
                if (this.onSelectedAll) {
                  this.onSelectedAll()
                }
              })
            }
          }

          if (this.showAIUser) {
            ForEach(this.aiUsers, (aiUser: V2NIMAIUser) => {
              ListItem() {
                Row() {
                  CommonAvatar({
                    item: new AvatarItem(
                      aiUser.avatar,
                      this.getAIUserAvatarName(aiUser),
                      AvatarColorUntil.getBackgroundColorById(aiUser.accountId)
                    )
                  })
                    .width(42)
                    .height(42)
                    .margin({
                      right: 14
                    })

                  Text(this.getAIUserShowName(aiUser))
                    .fontColor('#ff333333')
                    .fontSize(16)
                    .width('70%')
                }
                .padding({
                  left: 20,
                  right: 20,
                  top: 10,
                  bottom: 10
                })
                .onClick(() => {
                  this.closeDialog()
                  if (this.onAIUserSelected) {
                    this.onAIUserSelected(aiUser)
                  }
                })
              }
            })
          }

          if (this.showTeamMember) {
            ForEach(this.teamMemberCache.getAllMembers(), (member: TeamMemberWithUser) => {
              if (member.getAccId() !== ChatKitClient.getLoginUserId() &&
                !AIUserManager.isAIChatUser(member.getAccId())) {
              ListItem() {
                Row() {
                  CommonAvatar({
                    item: new AvatarItem(
                      member.getAvatar(),
                      member.getAvatarName(),
                      AvatarColorUntil.getBackgroundColorById(member.getAccId())
                    )
                  })
                    .width(42)
                    .height(42)
                    .margin({
                      right: 14
                    })

                  Text(member.getNickname())
                    .fontColor('#ff333333')
                    .fontSize(16)
                    .width('70%')
                }
                .padding({
                  left: 20,
                  right: 20,
                  top: 10,
                  bottom: 10
                })
                .onClick(() => {
                  this.closeDialog()
                  if (this.onMemberSelected) {
                    this.onMemberSelected(member)
                  }
                })
              }
            }
            })
          }

          ListItem() {
            Column() {
            }
            .height(42)
          }
        }
        .listDirection(Axis.Vertical)
        .onReachEnd(() => {
          this.teamMemberCache.getMoreMemberList()
        })
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('60%')
      .backgroundColor('#ffFFFFFF')
      .visibility(this.showFlag)
      .transition(TransitionEffect.OPACITY.animation({ duration: this.animationDur })
        .combine(TransitionEffect.translate({ y: 100 })))
    }
  }

  closeDialog() {
    this.showFlag = Visibility.Hidden
    setTimeout(() => {
      this.controller.close()
    }, this.animationDur)
  }

  aboutToAppear(): void {
    this.updateShowAitAllItem()
    this.getUIContext().getHostContext()?.eventHub.on('aitDialogClose', () => {
      this.closeDialog()
    })
  }

  /**
   * 更新是否要显示@All的操作
   */
  async updateShowAitAllItem() {
    if (!this.showAitAll) {
      this.showAll = false
      return
    }
    let team = await this.teamMemberCache.getTeam()
    if (team) {
      if (TeamRepo.isGroupTeam(team)) {
        this.showAll = true
        return
      }
      if (team?.serverExtension) {
        let obgExt = JSON.parse(team.serverExtension) as object | undefined
        if (obgExt) {
          if (obgExt[keyExtensionAtAll] === typeExtensionAllowAll) {
            this.showAll = true
            return
          }
        } else {
          this.showAll = true
          return
        }
      } else {
        this.showAll = true
        return
      }
    }
    let mineMember = await this.teamMemberCache.getMineMember()
    if (mineMember
      &&
      (mineMember.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER
        || mineMember.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER)) {
      this.showAll = true
      return
    }
    this.showAll = false
  }

  private getAIUserShowName(aiUser: V2NIMAIUser): string {
    return aiUser.name ?? aiUser.accountId
  }

  private getAIUserAvatarName(aiUser: V2NIMAIUser): string {
    let name = this.getAIUserShowName(aiUser)
    if (name.length > 2) {
      name = name.substring(name.length - 2, name.length)
    }
    return name
  }
}
