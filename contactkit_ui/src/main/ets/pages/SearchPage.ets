/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import {
  AvatarColorUntil,
  AvatarItem,
  CommonAvatar,
  CommonEmptyResult,
  CommonTextInput,
  ListGroupHeader,
  MatchSearchText,
  NavigationBackBuilder,
  TailString
} from '@nimkit/common';
import { SearchViewModel } from '../viewmodel/SearchViewModel';
import { SearchListModel } from '../model/SearchListModel';
import {
  ChatKitClient,
  getContactSearchRenderKey,
  normalizeSearchKeyword,
  resolveContactSearchTextPresentation,
  SearchTextPresentation
} from '@nimkit/chatkit';

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
  onTextChange = (value: string, previewText?: PreviewText) => {
    try {
      const keyword = normalizeSearchKeyword(value)
      this.searchText = keyword
      this.viewModel.doSearch(keyword)
    } catch (err) {
      Logger.error('ContactKit', err)
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

        if (this.isSearchResultEmpty()) {
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
                        item.userInfo?.getAvatarName(),
                        AvatarColorUntil.getBackgroundColorById(item.userInfo?.user?.accountId ?? "")),
                      roundRadius: 18
                    })
                      .width(36)
                      .height(36)
                      .margin({
                        left: 20
                      })

                    Column() {
                      if (item.userInfo) {
                        this.contactSearchResultTextBuilder(
                          item.userInfo.showName(),
                          resolveContactSearchTextPresentation(item.userInfo, this.searchText)
                        )
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
              }, (item: SearchListModel) => item.userInfo ?
                getContactSearchRenderKey(item.userInfo, this.searchText) : this.searchText)
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
              }, (item: SearchListModel) =>
                [item.team?.teamId ?? '', this.searchText, item.team?.name ?? ''].join('::'))
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
              }, (item: SearchListModel) =>
                [item.team?.teamId ?? '', this.searchText, item.team?.name ?? ''].join('::'))
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

  private isSearchResultEmpty(): boolean {
    return this.searchText.length > 0 && this.viewModel.friendData.length === 0 &&
      this.viewModel.discussData.length === 0 && this.viewModel.seniorData.length === 0
  }

  @Builder
  contactSearchResultTextBuilder(primaryText: string, presentation: SearchTextPresentation) {
    Column() {
      if (presentation.primaryMatched) {
        MatchSearchText({
          allText: primaryText,
          searchText: this.searchText.trim()
        })
      } else {
        Text(primaryText)
          .fontSize(14)
          .fontColor('#333333')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      if (presentation.secondaryText.length > 0) {
        MatchSearchText({
          allText: presentation.secondaryText,
          searchText: this.searchText.trim(),
          fontSize: 13,
          normalFontColor: '#999999',
          highlightFontColor: '#337EFF'
        })
      }
    }
    .alignItems(HorizontalAlign.Start)
  }

  aboutToDisappear(): void {
    this.viewModel.onDestroy()
  }
}
