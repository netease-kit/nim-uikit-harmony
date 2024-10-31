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
  CommonEmptyResult,
  CommonTextInput,
  ListGroupHeader,
  NavigationBackBuilder,
  TailString
} from '@nimkit/common';
import { SearchViewModel } from '../viewmodel/SearchViewModel';
import { SearchListModel } from '../model/SearchListModel';
import { ChatKitClient } from '@nimkit/chatkit';

@ComponentV2
struct MatchSearchText {
  @Param allText: string = ""
  @Param searchText: string = ""
  @Param fontSize: number = 14

  startOfSearchText() {
    return this.allText?.indexOf(this.searchText)
  }

  endOfSearchText() {
    return this.startOfSearchText() + this.searchText.length
  }

  build() {
    Text() {
      Span(this.allText.substring(0, this.startOfSearchText()))
        .fontSize(this.fontSize)
        .fontColor('#333333')

      Span(this.searchText)
        .fontColor('#337EFF')
        .fontSize(this.fontSize)

      Span(this.allText.substring(this.endOfSearchText(), this.allText.length))
        .fontSize(this.fontSize)
        .fontColor('#333333')

    }
  }
}

// 跳转页面入口函数
@Builder
export function SearchPageBuilder() {
  SearchPage()
}

@ComponentV2
export struct SearchPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local viewModel: SearchViewModel = new SearchViewModel()
  @Local searchText: string = ""
  @Local isEmpty: boolean = false
  onTextChange = (value: string, previewText?: PreviewText) => {
    try {
      this.searchText = value
      this.viewModel.doSearch(value)
      this.isEmpty =
        value.length > 0 && this.viewModel.friendData.length === 0 && this.viewModel.discussData.length === 0 &&
          this.viewModel.seniorData.length === 0
    } catch (err) {
      console.error(err)
    }
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.common_search'),
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        CommonTextInput({
          placeHolderText: $r('app.string.common_search_placeholder'),
          onTextChange: this.onTextChange,
          keepEditableState: false
        })

        if (this.isEmpty) {
          CommonEmptyResult()
            .margin({
              top: 74
            })
        }

        List() {
          // 好友
          if (this.viewModel.friendData.length > 0) {
            ListItemGroup({
              header: ListGroupHeader($r('app.string.search_result_friend'))
            }) {
              ForEach(this.viewModel.friendData, (item: SearchListModel) => {
                ListItem() {
                  Row() {
                    CommonAvatar({
                      item: new AvatarItem(item.userInfo?.user?.avatar,
                        item.userInfo?.shortName(),
                        AvatarColorUntil.getBackgroundColorById(item.userInfo?.user?.accountId ?? "")),
                      roundRadius: 18
                    })
                      .width(36)
                      .height(36)
                      .margin({
                        left: 20
                      })

                    Column() {
                      if (item.userInfo?.showName().includes(this.searchText)) {
                        MatchSearchText({
                          allText: item.userInfo?.showName(),
                          searchText: this.searchText
                        })
                      } else if (item.userInfo?.user?.accountId.includes(this.searchText)) {
                        Text(item.userInfo?.showName())
                          .fontSize(14)
                          .fontColor('#333333')
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })

                        MatchSearchText({
                          allText: item.userInfo?.user.accountId,
                          searchText: this.searchText,
                          fontSize: 13
                        })
                      }
                    }
                    .layoutWeight(1)
                    .margin({
                      left: 12,
                      right: 20
                    })
                    .alignItems(HorizontalAlign.Start)
                  }
                }
                .height(52)
                .onClick(() => {
                  const conversationId =
                    ChatKitClient.nim.conversationIdUtil.p2pConversationId(item.userInfo?.user?.accountId)
                  this.pathStack.pushPath({
                    name: 'ChatP2PPage',
                    param: conversationId
                  })
                })
              })
            }
          }

          // 讨论组
          if (this.viewModel.discussData.length > 0) {
            ListItemGroup({
              header: ListGroupHeader($r('app.string.search_result_discussion'))
            }) {
              ForEach(this.viewModel.discussData, (item: SearchListModel) => {
                ListItem() {
                  Row() {
                    CommonAvatar({
                      item: new AvatarItem(item.team?.avatar,
                        TailString(item.team?.name),
                        AvatarColorUntil.getBackgroundColorById(item.team?.teamId ?? "")),
                      roundRadius: 18
                    })
                      .width(36)
                      .height(36)
                      .margin({
                        left: 20
                      })

                    Column() {
                      MatchSearchText({
                        allText: item.team?.name,
                        searchText: this.searchText
                      })
                    }
                    .layoutWeight(1)
                    .margin({
                      left: 12,
                      right: 20
                    })
                    .alignItems(HorizontalAlign.Start)
                  }
                }
                .height(52)
                .onClick(() => {
                  const conversationId = ChatKitClient.nim.conversationIdUtil.teamConversationId(item.team?.teamId)
                  this.pathStack.pushPath({
                    name: 'ChatTeamPage',
                    param: conversationId
                  })
                })
              })
            }
          }

          // 高级群
          if (this.viewModel.seniorData.length > 0) {
            ListItemGroup({
              header: ListGroupHeader($r('app.string.search_result_senior'))
            }) {
              ForEach(this.viewModel.seniorData, (item: SearchListModel) => {
                ListItem() {
                  Row() {
                    CommonAvatar({
                      item: new AvatarItem(item.team?.avatar,
                        TailString(item.team?.name),
                        AvatarColorUntil.getBackgroundColorById(item.team?.teamId ?? "")),
                      roundRadius: 18
                    })
                      .width(36)
                      .height(36)
                      .margin({
                        left: 20
                      })

                    Column() {
                      MatchSearchText({
                        allText: item.team?.name,
                        searchText: this.searchText
                      })
                    }
                    .layoutWeight(1)
                    .margin({
                      left: 12,
                      right: 20
                    })
                    .alignItems(HorizontalAlign.Start)
                  }
                }
                .height(52)
                .onClick(() => {
                  const conversationId = ChatKitClient.nim.conversationIdUtil.teamConversationId(item.team?.teamId)
                  this.pathStack.pushPath({
                    name: 'ChatTeamPage',
                    param: conversationId
                  })
                })
              })
            }
          }
        }
        .margin({
          top: 2,
          bottom: 90
        })
      }
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
  }
}
