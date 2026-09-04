/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import {
  AIUserManager,
  ChatKitClient,
  getTeamMemberSearchRenderKey,
  keyExtensionAtAll,
  resolveTeamMemberSearchTextPresentation,
  SearchTextPresentation,
  TeamMemberCache,
  TeamMemberWithUser,
  TeamRepo,
  typeExtensionAllowAll
} from '@nimkit/chatkit'
import {
  AvatarColorUntil,
  AvatarItem,
  CommonAvatar,
  CommonEmptyResult,
  CommonTextInput,
  MatchSearchText
} from '@nimkit/common'
import { V2NIMAIUser, V2NIMTeam, V2NIMTeamMemberRole } from '@nimsdk/base'
import {
  AitSearchViewState,
  filterAitTeamMembers,
  getAitAIUserRenderKey,
  getAitAIUserShowName,
  isCurrentAitSearchRequest,
  resolveAitSearchViewState,
  resolveAitAIUserSearchTextPresentation,
  shouldLoadAllAitTeamMembers,
  shouldShowAitSpecialItems
} from '../common/AitMemberSearchUtils'
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
  @State searchKeyword: string = ''
  @State isSearching: boolean = false
  @State searchFinished: boolean = false
  @State searchLoadFailed: boolean = false
  @State searchResults: TeamMemberWithUser[] = []
  @State visibleMemberLimit: number = 100
  private searchGeneration: number = 0
  private aitDialogCloseListenerRegistered: boolean = false
  private aitDialogCloseListener: () => void = (): void => {
    this.closeDialog()
  }

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

        if (this.showTeamMember) {
          CommonTextInput({
            placeHolderText: $r('app.string.common_search_placeholder'),
            text: this.searchKeyword,
            onTextChange: (value: string) => {
              this.handleSearchKeywordChange(value)
            },
            onClear: () => {
              this.getUIContext().getFocusController().clearFocus()
            },
            activeBackgroundColor: $r('app.color.chat_ait_search_active_background')
          })
            .margin({
              top: 8,
              bottom: 8
            })
        }

        List() {
          if (this.showAll && shouldShowAitSpecialItems(this.searchKeyword)) {
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

          if (this.showAIUser && shouldShowAitSpecialItems(this.searchKeyword)) {
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

                  this.searchResultTextBuilder(
                    getAitAIUserShowName(aiUser),
                    resolveAitAIUserSearchTextPresentation(aiUser, this.searchKeyword)
                  )
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
            }, (aiUser: V2NIMAIUser) => getAitAIUserRenderKey(aiUser))
          }

          if (this.showTeamMember) {
            ForEach(this.getDisplayTeamMembers(),
              (member: TeamMemberWithUser) => {
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

                    this.searchResultTextBuilder(
                      member.getNickname(),
                      resolveTeamMemberSearchTextPresentation(member, this.searchKeyword)
                    )
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
              }, (member: TeamMemberWithUser) => getTeamMemberSearchRenderKey(member, this.searchKeyword))
          }

          if (this.getSearchViewState().showLoading) {
            ListItem() {
              Row({ space: 8 }) {
                LoadingProgress()
                  .width(24)
                  .height(24)

                Text($r('app.string.chat_team_ait_search_loading'))
                  .fontSize(14)
                  .fontColor('#999999')
              }
              .width('100%')
              .height(62)
              .justifyContent(FlexAlign.Center)
            }
          }

          if (this.getSearchViewState().showEmpty) {
            ListItem() {
              CommonEmptyResult({
                tips: $r('app.string.chat_team_ait_search_empty')
              })
                .height(220)
            }
          }

          ListItem() {
            Column() {
            }
            .height(42)
          }
        }
        .listDirection(Axis.Vertical)
        .onReachEnd(() => {
          if (this.searchKeyword.trim().length === 0) {
            this.visibleMemberLimit += 100
            this.teamMemberCache.getMoreMemberList()
          }
        })
        .scrollBar(BarState.Off)
        .width('100%')
        .layoutWeight(1)
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
    this.unregisterAitDialogCloseListener()
    if (this.showFlag === Visibility.Hidden) {
      return
    }
    this.searchGeneration += 1
    this.searchKeyword = ''
    this.isSearching = false
    this.searchFinished = false
    this.searchLoadFailed = false
    this.searchResults = []
    this.visibleMemberLimit = 100
    this.showFlag = Visibility.Hidden
    setTimeout(() => {
      this.controller.close()
    }, this.animationDur)
  }

  aboutToAppear(): void {
    this.searchGeneration += 1
    this.searchKeyword = ''
    this.isSearching = false
    this.searchFinished = false
    this.searchLoadFailed = false
    this.searchResults = []
    this.visibleMemberLimit = 100
    this.showFlag = Visibility.Visible
    this.updateShowAitAllItem()
    this.registerAitDialogCloseListener()
  }

  aboutToDisappear(): void {
    this.searchGeneration += 1
    this.unregisterAitDialogCloseListener()
  }

  /**
   * 更新是否要显示@All的操作
   */
  async updateShowAitAllItem() {
    if (!this.showAitAll) {
      this.showAll = false
      return
    }
    let team = await this.teamMemberCache.getTeam(this.teamId)
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
    let mineMember = await this.teamMemberCache.getMineMember(this.teamId)
    if (mineMember
      &&
      (mineMember.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER
        || mineMember.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER)) {
      this.showAll = true
      return
    }
    this.showAll = false
  }

  @Builder
  searchResultTextBuilder(primaryText: string, presentation: SearchTextPresentation) {
    Column() {
      if (presentation.primaryMatched) {
        MatchSearchText({
          allText: primaryText,
          searchText: this.searchKeyword.trim(),
          fontSize: 16
        })
      } else {
        Text(primaryText)
          .fontColor('#ff333333')
          .fontSize(16)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      if (presentation.secondaryText.length > 0) {
        MatchSearchText({
          allText: presentation.secondaryText,
          searchText: this.searchKeyword.trim(),
          fontSize: 13,
          normalFontColor: '#999999',
          highlightFontColor: '#337EFF'
        })
      }
    }
    .width('70%')
    .alignItems(HorizontalAlign.Start)
  }

  private getAIUserAvatarName(aiUser: V2NIMAIUser): string {
    let name = getAitAIUserShowName(aiUser)
    if (name.length > 2) {
      name = name.substring(name.length - 2, name.length)
    }
    return name
  }

  private async handleSearchKeywordChange(value: string): Promise<void> {
    this.searchKeyword = value
    this.searchGeneration += 1
    const currentSearchGeneration = this.searchGeneration
    const currentTeamId = this.teamId
    this.searchLoadFailed = false
    this.searchFinished = false
    if (value.trim().length === 0 || !this.showTeamMember) {
      this.isSearching = false
      this.searchResults = []
      return
    }

    if (this.teamId) {
      this.teamMemberCache.intTeamInfo(this.teamId, this.team)
    }
    this.searchResults = this.getTeamMemberSearchResults(value)
    const alreadyLoadedAll = this.teamMemberCache.haveLoadAllMember(currentTeamId)
    if (!shouldLoadAllAitTeamMembers(value, this.showTeamMember, alreadyLoadedAll)) {
      this.isSearching = false
      this.searchFinished = alreadyLoadedAll
      return
    }

    this.isSearching = true
    const loadSucceeded = await this.teamMemberCache.loadAllTeamMember()
    if (!isCurrentAitSearchRequest(
      currentSearchGeneration,
      this.searchGeneration,
      value,
      this.searchKeyword,
      currentTeamId,
      this.teamId
    )) {
      return
    }
    if (loadSucceeded) {
      this.searchResults = this.getTeamMemberSearchResults(value)
    }
    this.searchFinished = loadSucceeded
    this.searchLoadFailed = !loadSucceeded
    this.isSearching = false
  }

  private getDisplayTeamMembers(): TeamMemberWithUser[] {
    if (this.searchKeyword.trim().length > 0) {
      if (this.isSearching || this.searchLoadFailed) {
        return this.searchResults
      }
      return this.getTeamMemberSearchResults(this.searchKeyword)
    }
    return this.filterNormalTeamMembers(
      this.teamMemberCache.getAllMembers(this.teamId).slice(0, this.visibleMemberLimit)
    )
  }

  private getTeamMemberSearchResults(keyword: string): TeamMemberWithUser[] {
    const matchedMembers = filterAitTeamMembers(
      this.teamMemberCache.getAllMembers(this.teamId), keyword
    ).filter((member: TeamMemberWithUser): boolean => {
      return member.getAccId() !== ChatKitClient.getLoginUserId()
    })
    const aiTeamMembers: TeamMemberWithUser[] = []
    const normalTeamMembers: TeamMemberWithUser[] = []
    matchedMembers.forEach((member: TeamMemberWithUser): void => {
      if (AIUserManager.isAIChatUser(member.getAccId())) {
        aiTeamMembers.push(member)
      } else {
        normalTeamMembers.push(member)
      }
    })
    // 搜索结果保持 AI 群成员优先，普通成员顺序沿用群成员排序
    return aiTeamMembers.concat(normalTeamMembers)
  }

  private filterNormalTeamMembers(members: TeamMemberWithUser[]): TeamMemberWithUser[] {
    return members.filter((member: TeamMemberWithUser): boolean => {
      // 空关键词时 AI 数字人通过独立入口展示，普通成员区避免重复
      return member.getAccId() !== ChatKitClient.getLoginUserId() &&
        !AIUserManager.isAIChatUser(member.getAccId())
    })
  }

  private getSearchViewState(): AitSearchViewState {
    const resultCount = this.searchResults.length > 0 ?
      this.searchResults.length : this.getDisplayTeamMembers().length
    return resolveAitSearchViewState(
      this.searchKeyword,
      this.isSearching,
      this.searchFinished,
      resultCount
    )
  }

  private registerAitDialogCloseListener(): void {
    this.unregisterAitDialogCloseListener()
    const eventHub = this.getUIContext().getHostContext()?.eventHub
    if (eventHub) {
      eventHub.on('aitDialogClose', this.aitDialogCloseListener)
      this.aitDialogCloseListenerRegistered = true
    }
  }

  private unregisterAitDialogCloseListener(): void {
    if (!this.aitDialogCloseListenerRegistered) {
      return
    }
    this.getUIContext().getHostContext()?.eventHub.off('aitDialogClose', this.aitDialogCloseListener)
    this.aitDialogCloseListenerRegistered = false
  }

}
