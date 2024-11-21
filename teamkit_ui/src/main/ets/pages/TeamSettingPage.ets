/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  AvatarColorUntil,
  AvatarItem,
  CommonAvatar,
  CommonConfirmDialog,
  NavigationBackBuilder,
  NECommonUtils,
  TextEditParams
} from '@nimkit/common'
import {
  V2NIMError,
  V2NIMTeamChatBannedMode,
  V2NIMTeamInviteMode,
  V2NIMTeamMemberRole,
  V2NIMTeamType
} from '@nimsdk/base'
import { TeamMemberWithUser } from '@nimkit/chatkit/src/main/ets/model/TeamMemberWithUser'
import { TeamSettingViewModel } from '../viewModel/TeamViewModel'
import { ChatKitClient, NEUserWithFriend, PersonSelectParam, TeamRepo } from '@nimkit/chatkit'
import { MemberListParams } from './TeamMemberListPage'

@ComponentV2
export struct TeamSettingPage {
  pathStack: NavPathStack = new NavPathStack()
  teamId: string = ''
  // @Local team?:V2NIMTeam
  //
  // @Local teamMemberList:V2NIMTeamMember[] = []

  teamViewModel?: TeamSettingViewModel
  dialogLeaveGroupTeamDialogController: CustomDialogController = new CustomDialogController({
    builder: CommonConfirmDialog({
      title: $r('app.string.team_group_left'),
      confirmContent: $r('app.string.team_group_left_content'),
      confirm: () => {
        this.leftGroupTeam()
      },
    }),
  })
  dialogDismissTeamController: CustomDialogController = new CustomDialogController({
    builder: CommonConfirmDialog({
      title: $r('app.string.team_dismiss'),
      confirmContent: $r('app.string.team_dismiss_content'),
      confirm: () => {
        this.dismissTeam()
      },
    }),
  })
  dialogLeaveTeamController: CustomDialogController = new CustomDialogController({
    builder: CommonConfirmDialog({
      title: $r('app.string.team_left'),
      confirmContent: $r('app.string.team_left_content'),
      confirm: () => {
        this.leftTeam()
      },
    }),
  })

  build() {
    NavDestination() {
      NavigationBackBuilder({
        title: $r('app.string.team_setting'),
        backgroundColor: '#ffEFF1F4',
        leftButtonAction: () => {
          this.pathStack.pop()
        }
      })
      if (this.teamViewModel?.team) {
        Column() {
          Column() {
            Row() {
              CommonAvatar({
                item: new AvatarItem(this.teamViewModel.team.avatar,
                  this.teamViewModel.team.name,
                  AvatarColorUntil.getBackgroundColorById(this.teamViewModel.team.teamId)),
                roundRadius: 18
              })
                .width(42)
                .height(42)
                .margin({
                  right: 12
                })

              Text(this.teamViewModel.team.name)
                .fontColor('ff333333')
                .fontSize(16)
                .width('80%')
                .maxLines(1)
                .ellipsisMode(EllipsisMode.END)
                .margin({
                  right: 12
                })

              Blank().layoutWeight(1)

              Button({
                type: ButtonType.Capsule
              }) {
                Image($r('app.media.arrow_right'))
                  .width(4.92)
                  .height(9.54)
              }
              .backgroundColor(Color.Transparent)
              .width(16)
              .height(16)
              .onClick(() => {
                this.pathStack.pushPath({
                  name: 'TeamInfoPage',
                  param: this.teamViewModel?.team
                })
              })

            }.margin({
              bottom: 12, right: 16
            })

            Divider()
              .color('#ffF5F8FC').height(1)

            Row() {
              Text(this.isGroupTeam() ? $r('app.string.team_group_member') :
              $r('app.string.team_member'))
                .fontSize(16)
                .fontColor('#ff333333')

              Blank().layoutWeight(1)

              Text(this.teamViewModel.team.memberCount + '')
                .fontColor('#ff999999')
                .fontSize(16).margin({
                right: 8
              })

              Image($r('app.media.arrow_right'))
                .width(4.92)
                .height(9.54)
            }.margin({
              top: 12,
              bottom: 12
            }).onClick(() => {
              let params: MemberListParams = {
                caseRole: !this.isGroupTeam(),
                teamId: this.teamId
              }
              this.pathStack.pushPath({
                name: 'TeamMemberListPage',
                param: params
              })
            })

            List({
              space: 15
            }) {
              if (this.haveAddTeamMemberPermission()) {
                ListItem() {
                  Image($r('app.media.team_invite'))
                    .width(32)
                    .height(32)
                    .onClick(() => {
                      //goto invite new team member
                      this.gotoAddNewMember()
                    })
                }
              }

              ForEach(this.teamViewModel.teamMemberList, (teamMember: TeamMemberWithUser) => {
                ListItem() {
                  CommonAvatar({
                    item: new AvatarItem(teamMember.getAvatar(),
                      teamMember.getAvatarName().slice(teamMember.getAvatarName().length > 2 ?
                        teamMember.getAvatarName().length - 2 : 0),
                      AvatarColorUntil.getBackgroundColorById(teamMember.getAccId()))
                  }).width(32)
                    .height(32)
                    .onClick(() => {
                      if (teamMember.teamMember.accountId === ChatKitClient.getLoginUserId()) {
                        this.pathStack.pushPath({
                          name: 'MineInfoPage'
                        })
                      } else {
                        this.pathStack.pushPath({ name: 'PersonInfoPage', param: teamMember.teamMember.accountId })
                      }
                    })
                }
              })
            }
            .scrollBar(BarState.Off)
            .width('100%')
            .height(32)
            .listDirection(Axis.Horizontal)
          }
          .width('100%')
          .padding({
            left: 16,
            right: 16,
            top: 16,
            bottom: 16
          })
          .margin({
            bottom: 12
          })
          .alignItems(HorizontalAlign.Start)
          .borderRadius(8)
          .backgroundColor('#ffffffff')


          Column() {
            Row() {
              Text($r('app.string.setting_pin'))
                .fontSize(16)
                .fontColor('#ff333333')

              Blank().layoutWeight(1)

              Image($r('app.media.arrow_right'))
                .width(4.92)
                .height(9.54)
            }
            .height(40)
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .onClick(() => {
              const conversationId = ChatKitClient.nim.conversationIdUtil.teamConversationId(this.teamViewModel?.teamId)
              this.pathStack.pushPath({
                name: 'PinMessagePage',
                param: conversationId,
              })
            })

            Row() {
              Text($r('app.string.team_history_record'))
                .fontSize(16)
                .fontColor('#ff333333')

              Blank().layoutWeight(1)

              Image($r('app.media.arrow_right'))
                .width(4.92)
                .height(9.54)
            }
            .height(40)
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .onClick(() => {
              this.pathStack.pushPath({
                name: 'TeamHistoryPage',
                param: this.teamViewModel?.teamId,
              })
            })

            Row() {
              Text($r("app.string.setting_message_notify"))
                .fontSize(16)
                .fontColor('#ff333333')

              Blank().layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.teamViewModel?.isMessageNotify })
                .selectedColor("#337EFF")
                .width(46)
                .height(28)
                .onClick(() => {
                  let isOn = this.teamViewModel?.isMessageNotify ?? false
                  this.teamViewModel?.setTeamNotify(!isOn)
                })
            }
            .height(40)
            .width('100%')
            .alignItems(VerticalAlign.Center)

            Divider()
              .color('#ffF5F8FC').height(1)

            Row() {
              Text($r("app.string.setting_message_stick_top"))
                .fontSize(16)
                .fontColor('#ff333333')

              Blank().layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.teamViewModel?.isStickTop })
                .selectedColor("#337EFF")
                .width(46)
                .height(28)
                .onClick(() => {
                  let isOn = this.teamViewModel?.isStickTop ?? false
                  this.teamViewModel?.stickTopConversation(!isOn)
                })
            }
            .height(40)
            .width('100%')
            .alignItems(VerticalAlign.Center)


            if (!this.isGroupTeam()) {
              Divider()
                .color('#ffF5F8FC').height(1)

              Row() {
                Text($r('app.string.team_nick'))
                  .fontSize(16)
                  .fontColor('#ff333333')

                Blank().layoutWeight(1)

                Image($r('app.media.arrow_right'))
                  .width(4.92)
                  .height(9.54)
              }
              .height(40)
              .width('100%')
              .alignItems(VerticalAlign.Center)
              .onClick(() => {
                const params: TextEditParams = {
                  content: this.teamViewModel?.mineTeamMember?.teamNick ?? '',
                  title: $r('app.string.team_nick'),
                  maxLength: 30,
                  showSave: true
                }
                this.pathStack.pushPath({
                  name: 'TextEditPage',
                  param: params,
                  onPop: (popInfo: PopInfo) => {
                    let teamNick = popInfo.result as string | undefined
                    if (teamNick !== undefined) {
                      this.teamViewModel?.updateTeamNick(teamNick)
                    }
                  }
                })
              })
            }
          }
          .width('100%')
          .padding({
            left: 16,
            right: 16
          })
          .margin({
            bottom: 12
          })
          .alignItems(HorizontalAlign.Start)
          .borderRadius(8)
          .backgroundColor('#ffffffff')

          if (
            !this.isGroupTeam() && (
              this.teamViewModel?.mineTeamMember?.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER ||
                this.teamViewModel?.mineTeamMember?.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER
            )
          ) {
            Column() {

              if (this.teamViewModel?.mineTeamMember?.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER) {
                Row() {
                  Text($r('app.string.team_mute'))
                    .fontSize(16)
                    .fontColor('#ff333333')

                  Blank().layoutWeight(1)

                  Toggle({
                    type: ToggleType.Switch,
                    isOn: this.teamViewModel?.team.chatBannedMode ===
                    V2NIMTeamChatBannedMode.V2NIM_TEAM_CHAT_BANNED_MODE_BANNED_NORMAL
                  })
                    .selectedColor("#337EFF")
                    .width(46)
                    .height(28)
                    .onClick(() => {
                      let isOn: boolean = this.teamViewModel?.team?.chatBannedMode ===
                      V2NIMTeamChatBannedMode.V2NIM_TEAM_CHAT_BANNED_MODE_BANNED_NORMAL
                      this.teamViewModel?.bannedTeam(!isOn)
                    })
                }
                .height(40)
                .width('100%')
                .alignItems(VerticalAlign.Center)

                Divider()
                  .color('#ffF5F8FC').height(1)
              }

              Row() {
                Text($r('app.string.team_manage'))
                  .fontSize(16)
                  .fontColor('#ff333333')

                Blank().layoutWeight(1)

                Image($r('app.media.arrow_right'))
                  .width(4.92)
                  .height(9.54)
              }
              .height(40)
              .width('100%')
              .alignItems(VerticalAlign.Center)
              .onClick(() => {
                // goto  team manage page
                this.pathStack.pushPath({
                  name: 'TeamManagePage',
                  param: this.teamViewModel?.team
                })
              })

            }
            .width('100%')
            .padding({
              left: 16,
              right: 16
            })
            .margin({
              bottom: 12
            })
            .alignItems(HorizontalAlign.Start)
            .borderRadius(8)
            .backgroundColor('#ffffffff')
          }

          if (this.isGroupTeam()) {
            Button($r('app.string.team_group_left'), { type: ButtonType.Normal, stateEffect: true })
              .borderRadius(8)
              .backgroundColor(Color.White)
              .fontColor('#ffE6605C')
              .fontSize(16)
              .width('100%')
              .height(40)
              .onClick(() => {
                this.showLeaveGroupTeamDialog()
              })
          } else {
            Button(
              this.teamViewModel?.mineTeamMember?.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER ?
              $r('app.string.team_dismiss') :
              $r('app.string.team_left'),
              { type: ButtonType.Normal, stateEffect: true })
              .borderRadius(8)
              .backgroundColor(Color.White)
              .fontColor('#ffE6605C')
              .fontSize(16)
              .width('100%')
              .height(40)
              .onClick(() => {
                if (this.teamViewModel?.mineTeamMember?.memberRole ===
                V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER) {
                  this.showDismissTeamDialog()
                } else {
                  this.showLeaveTeamDialog()
                }
              })
          }


        }
        .width('100%')
        .height('100%')
        .padding({
          left: 20,
          right: 20,
          top: 18,
          bottom: 18

        })
        .backgroundColor('#ffEFF1F4')
      }

    }
    .hideTitleBar(true)
    .backgroundColor('#ffEFF1F4')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.requestTeamInfo()
    })
  }

  aboutToDisappear(): void {
    this.dialogLeaveTeamController.close()
    this.dialogLeaveGroupTeamDialogController.close()
    this.dialogDismissTeamController.close()
    this.teamViewModel?.destroy()
  }

  //弹框退出讨论组
  showLeaveGroupTeamDialog() {
    this.dialogLeaveGroupTeamDialogController.open()
  }

  //退出讨论组
  async leftGroupTeam() {
    ChatKitClient.selfLeaveTeam = true
    try {
      //如果只有一个人了直接解散
      if (this.teamViewModel?.team?.memberCount !== undefined &&
        this.teamViewModel?.team?.memberCount <= 1) {
        this.dismissTeam()
      }
      //如果是群主，先转让群,否则，直接退出
      if (this.teamViewModel?.mineTeamMember?.memberRole ===
      V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER) {
        await TeamRepo.transferTeamOwner(
          this.teamId,
          V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
          this.teamViewModel?.teamMemberList.find(member => member.teamMember.accountId !==
          ChatKitClient.getLoginUserId())?.getAccId() ?? '',
          true
        )
        this.pathStack.clear()
      } else {
        this.leftTeam()
      }
    } catch (e) {

    }
  }

  //弹框解散群组
  showDismissTeamDialog() {
    this.dialogDismissTeamController.open()
  }

  //解散群组
  dismissTeam() {
    ChatKitClient.selfLeaveTeam = true
    TeamRepo.dismissTeam(this.teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL).then(() => {
      const pathNames = this.pathStack.getAllPathName()
      if (pathNames.includes('MyTeamsPage')) {
        this.pathStack.popToName('MyTeamsPage')
      } else {
        this.pathStack.clear()
      }
    })
  }

  //弹框退出群组
  showLeaveTeamDialog() {
    this.dialogLeaveTeamController.open()
  }

  //退出群组
  leftTeam() {
    ChatKitClient.selfLeaveTeam = true
    TeamRepo.leaveTeam(this.teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL).then(() => {
      const pathNames = this.pathStack.getAllPathName()
      if (pathNames.includes('MyTeamsPage')) {
        this.pathStack.popToName('MyTeamsPage')
      } else {
        this.pathStack.clear()
      }
    })
  }

  //是否有添加成员的权限
  haveAddTeamMemberPermission(): boolean {
    if (this.teamViewModel?.team) {
      if (TeamRepo.isGroupTeam(this.teamViewModel?.team)) {
        return true
      }
      if (this.teamViewModel?.team.inviteMode == V2NIMTeamInviteMode.V2NIM_TEAM_INVITE_MODE_ALL) {
        return true
      } else if (
        this.teamViewModel?.mineTeamMember?.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER ||
          this.teamViewModel?.mineTeamMember?.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER
      ) {
        return true
      }
    }
    return false

  }

  //是否是讨论组
  isGroupTeam(): boolean {
    if (this.teamViewModel?.team) {
      return TeamRepo.isGroupTeam(this.teamViewModel?.team)
    }
    return false
  }

  requestTeamInfo() {
    let index = this.pathStack.getIndexByName('TeamSettingPage')
    this.teamId = this.pathStack.getParamByIndex(index[0]) as string
    this.teamViewModel = new TeamSettingViewModel(this.teamId)
    this.teamViewModel.initTeamInfo()
  }

  // 邀请人入群选择返回
  teamSelectorCallback = async (selectedList: NEUserWithFriend[]) => {
    try {
      this.pathStack.pop()
      if (!this.haveAddTeamMemberPermission()) {
        NECommonUtils.showToast($r('app.string.team_operate_no_permission_tip'))
        return
      }
      let invitees = selectedList.map(user => user.user?.accountId ?? '')
      TeamRepo.inviteMember(this.teamId,
        V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        invitees
      ).then((accIds) => {
        ChatKitClient.logger?.debug(`inviteMember success ${accIds.join(',')}`)
      })
        .catch((e: V2NIMError) => {
          ChatKitClient.logger?.debug(`inviteMember faile ${e.message}`)
          NECommonUtils.showToast($r('app.string.common_operate_failed'))
        })
    } catch (err) {
      ChatKitClient.logger?.debug(err)
    }
  }

  //添加新成员
  gotoAddNewMember() {
    this.pathStack.pushPath({
      name: "PersonSelectPage",
      param: new PersonSelectParam(this.teamSelectorCallback,
        this.teamViewModel?.teamMemberList.map(member => member.getAccId()),
        this.getMemberInviteCountLimit()
      )
    })
  }

  //获取群邀请人数限制
  getMemberInviteCountLimit(): number {
    if (this.teamViewModel?.team) {
      return this.teamViewModel?.team?.memberLimit - this.teamViewModel?.team?.memberCount
    }
    return 200
  }
}

// 跳转页面入口函数
@Builder
export function TeamSettingPageBuilder() {
  TeamSettingPage()
}