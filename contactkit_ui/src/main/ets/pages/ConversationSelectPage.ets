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
  ListGroupHeader,
  NavigationBackBuilder,
  NECommonUtils,
  ViewItemBuilder
} from '@nimkit/common';
import { ChatKitClient, ConversationSelectedParam, ConversationSelectParam, ErrorUtils } from '@nimkit/chatkit';
import { ConversationSelectViewModel } from '../viewmodel/ConversationSelectViewModel';
import { NEContactSection, SelectUserWithFriend } from '../model/NEContactSection';
import { ConversationSelectModel } from '@nimkit/chatkit/src/main/ets/model/ConversationSelectModel';

// 跳转页面入口函数
@Builder
export function ConversationSelectPageBuilder() {
  ConversationSelectPage()
}


/// 会话选择页面
@ComponentV2
export struct ConversationSelectPage {
  pathStack: NavPathStack = new NavPathStack()
  filterList?: string[] = []
  selectLimit: number = 200
  onSureButtonClick?: (selectedList: ConversationSelectModel[]) => void = undefined
  @Local selectedList: ConversationSelectModel[] = []
  @Local selectedIndex: number = 0; // 用于指定字母导航的选择项
  @Local currentIndex: number = 0
  @Local isMultiSelect: boolean = false // 是否多选，默认单选模式
  @Local rightButtonTitle: ResourceStr = $r('app.string.conversation_select_multi')
  @Local rightButtonColor: ResourceColor = '#666666'
  private viewModel: ConversationSelectViewModel = new ConversationSelectViewModel()
  // List组件的scroller控制器：listScroller，用于控制联系人列表的滑动位置
  private listScroller: Scroller = new Scroller()

  async requestData() {
    const param = this.pathStack.getParamByName('ConversationSelectPage')[0] as ConversationSelectParam
    if (param) {
      this.filterList = param.filterList
      this.selectLimit = param.selectLimit
      this.onSureButtonClick = param.onSureButtonClick
    }

    try {
      await this.viewModel.loadData(this.filterList)
    } catch (err) {
      console.error(err)
    }
  }

  callback = () => {
    if (this.selectedList.length > 0) {
      if (ErrorUtils.checkNetworkAndToast() && this.onSureButtonClick) {
        this.onSureButtonClick(this.selectedList)
        this.pathStack.pop()
      }
    }
  }
  sureButtonClickAction = () => {
    if (!this.isMultiSelect) {
      this.isMultiSelect = true
      this.selectedList = []
      this.setRightButtonTitle()
      return
    }

    this.callback()
  }

  @Monitor('selectedList.length')
  setRightButtonTitle() {
    if (this.selectedList.length > 0) {
      this.rightButtonTitle = $r('app.string.common_sure_count', this.selectedList.length)
      this.rightButtonColor = '#337EFF'
    } else {
      this.rightButtonTitle = $r('app.string.common_sure')
      this.rightButtonColor = '#CCCCCC'
    }
  }

  // 移除按钮点击事件
  removeButtonAction = (item: ConversationSelectModel) => {
    if (item.conversationId) {
      for (let index = 0; index < this.selectedList.length; index++) {
        if (this.selectedList[index].conversationId === item.conversationId) {
          this.selectedList.splice(index, 1)
          item.isSelected = false

          const accountId =
            ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(item.conversationId)
          let contactModel = this.viewModel.contactViewModel.findContactModel(accountId)
          if (contactModel) {
            contactModel.selected = false
          }
        }
      }
    }
  }

  @Builder
  tabBuilder(index: number, name: string | Resource) {
    Column() {
      Text(name)
        .height(16)
        .fontColor(this.currentIndex === index ? '#337EFF' : '#333333')
        .font({
          size: 14,
          weight: this.currentIndex === index ? 500 : 400
        })
        .margin({
          top: 10,
          bottom: 10
        })
      Stack({ alignContent: Alignment.Bottom }) {
        Divider()
          .strokeWidth(1)
          .color('#E9EFF5')
          .opacity(this.currentIndex === index ? 0 : 1)

        Divider()
          .strokeWidth(2)
          .color('#337EFF')
          .opacity(this.currentIndex === index ? 1 : 0)
      }
      .margin({
        top: 3
      })
    }
    .width('100%')
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.End }) {
        Stack() {
          Column() {
            NavigationBackBuilder({
              title: $r('app.string.person_select'),
              showDivideLine: false,
              leftButtonTitle: $r('app.string.mine_edit_cancel'),
              leftButtonColor: '#666666',
              leftButtonAction: () => {
                this.pathStack.pop()
              },
              rightButtonTitle: this.rightButtonTitle,
              rightButtonColor: this.rightButtonColor,
              rightButtonAction: this.sureButtonClickAction,
              buttonTextWidth: 80
            })

            if (this.isMultiSelect && this.selectedList.length > 0) {
              Row() {
                List({ space: 10 }) {
                  ForEach(this.selectedList, (item: ConversationSelectModel) => {
                    ListItem() {
                      CommonAvatar({
                        item: new AvatarItem(item.avatar, NECommonUtils.shortName(item.name),
                          AvatarColorUntil.getBackgroundColorById(item.conversationId ?? "")),
                        roundRadius: 16
                      })
                        .height(32)
                        .width(32)
                        .margin({
                          top: 10
                        })
                    }
                    .width(32)
                    .height(32)
                  })
                }
                .listDirection(Axis.Horizontal)
                .scrollBar(BarState.Off)
                .width(316)
                .backgroundColor(Color.White)
                .padding({
                  left: 16,
                  right: 16
                })

                Image($r('app.media.arrow_right'))
                  .width(4.92)
                  .height(9.54)
                  .margin({
                    left: 35
                  })
              }
              .width('100%')
              .height(52)
              .alignSelf(ItemAlign.Start)
              .backgroundColor(Color.White)
              .onClick(() => {
                this.pathStack.pushPath({
                  name: 'ConversationSelectedPage',
                  param: new ConversationSelectedParam(this.selectedList, this.removeButtonAction)
                })
              })
            }

            Tabs() {
              // 最近会话
              TabContent() {
                if (this.viewModel.conversationList.length <= 0) {
                  CommonEmptyResult({
                    tips: $r('app.string.conversation_empty')
                  })
                } else {
                  List({ scroller: this.listScroller }) {
                    ForEach(this.viewModel.conversationList, (item: ConversationSelectModel) => {
                      ListItem() {
                        Row() {
                          if (this.isMultiSelect) {
                            Image(item.isSelected ? $r('app.media.select_yes') : $r('app.media.select_no'))
                              .height(18)
                              .width(18)
                              .margin({
                                left: 20,
                                right: -10
                              })
                          }

                          Row() {
                            CommonAvatar({
                              item: new AvatarItem(item.avatar, NECommonUtils.shortName(item.name),
                                AvatarColorUntil.getBackgroundColorById(item.conversationId ?? ""))
                            })
                              .width(36)
                              .height(36)
                              .borderRadius(18)

                            Text(item.name)
                              .fontSize(14)
                              .fontColor("#333333")
                              .height(18)
                              .margin({ left: 12, right: 12 })
                              .layoutWeight(1)
                              .maxLines(1)
                              .textOverflow({ overflow: TextOverflow.Ellipsis })
                              .ellipsisMode(EllipsisMode.END)

                            if (item.memberCount > 0) {
                              Text(`(${item.memberCount})`)
                                .width(this.isMultiSelect ? 70 : 50)
                                .fontSize(14)
                                .fontColor("#333333")
                                .height(18)
                                .maxLines(1)
                                .textOverflow({ overflow: TextOverflow.Ellipsis })
                                .ellipsisMode(EllipsisMode.END)
                            }
                          }
                          .alignSelf(ItemAlign.Center)
                          .height(60)
                          .margin({ left: 20, right: 20 })
                        }
                      }
                      .width('100%')
                      .height(60)
                      .backgroundColor(Color.White)
                      .onClick(() => {
                        if (item.conversationId) {
                          // 单选
                          if (!this.isMultiSelect) {
                            this.selectedList = [item]
                            this.callback()
                            return
                          }

                          // 同步修改好友列表
                          const accountId =
                            ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(item.conversationId)
                          let contactModel = this.viewModel.contactViewModel.findContactModel(accountId)
                          if (item.isSelected) {
                            for (let index = 0; index < this.selectedList.length; index++) {
                              if (this.selectedList[index].conversationId === item.conversationId) {
                                this.selectedList.splice(index, 1)
                                item.isSelected = false
                                if (contactModel) {
                                  contactModel.selected = false
                                }
                              }
                            }
                          } else {
                            if (this.selectedList.length < this.selectLimit) {
                              this.selectedList.push(item)
                              item.isSelected = true
                              if (contactModel) {
                                contactModel.selected = true
                              }
                            } else {
                              NECommonUtils.showToast($r('app.string.conversation_select_limit_tip', this.selectLimit))
                            }
                          }
                        }
                      })
                    })
                  }
                  .width('100%')
                  .height('100%')
                  .backgroundColor('#EFF1F4')
                  .scrollBar(BarState.Off)
                }
              }
              .tabBar(this.tabBuilder(0, $r('app.string.conversation_select_conversation')))

              // 我的好友
              TabContent() {
                if (this.viewModel.contactViewModel.friendSection.contactSections.length <= 0) {
                  CommonEmptyResult({
                    tips: $r('app.string.no_friend')
                  })
                } else {
                  List({ scroller: this.listScroller }) {
                    LazyForEach(this.viewModel.contactViewModel.friendSection, (item: NEContactSection) => {
                      ListItemGroup({
                        header: ListGroupHeader(item.initial)
                      }) {
                        LazyForEach(item.contacts, (item: SelectUserWithFriend) => {
                          ListItem() {
                            Row() {
                              if (this.isMultiSelect) {
                                Image(item.selected ? $r('app.media.select_yes') : $r('app.media.select_no'))
                                  .height(18)
                                  .width(18)
                                  .margin({
                                    left: 20,
                                    right: -10
                                  })
                              }

                              ViewItemBuilder({
                                avatarItem: new AvatarItem(item.user?.avatar, item.shortName(),
                                  AvatarColorUntil.getBackgroundColorById(ChatKitClient.nim.conversationIdUtil.p2pConversationId(item.user?.accountId))),
                                title: item.showName(),
                                itemHeight: 60,
                                titleIconSize: 36,
                                titleFontSize: 14,
                                rightIcon: $r('app.string.validation_empty'), // 仅做占位
                                showDivideLine: false,
                              })
                            }
                          }
                          .width('100%')
                          .height(60)
                          .backgroundColor(Color.White)
                          .onClick(() => {
                            const conversationId =
                              ChatKitClient.nim.conversationIdUtil.p2pConversationId(item.user?.accountId)
                            const contactModel = this.viewModel.contactList.find(
                              contact => contact.conversationId === conversationId
                            )

                            if (contactModel) {
                              // 单选
                              if (!this.isMultiSelect) {
                                this.selectedList = [contactModel]
                                this.callback()
                                return
                              }

                              // 多选
                              if (item.selected) {
                                for (let index = 0; index < this.selectedList.length; index++) {
                                  if (this.selectedList[index].conversationId === conversationId) {
                                    this.selectedList.splice(index, 1)
                                    contactModel.isSelected = false
                                    item.selected = false
                                  }
                                }
                              } else {
                                if (this.selectedList.length < this.selectLimit) {
                                  this.selectedList.push(contactModel)
                                  contactModel.isSelected = true
                                  item.selected = true
                                } else {
                                  NECommonUtils.showToast($r('app.string.conversation_select_limit_tip',
                                    this.selectLimit))
                                }
                              }
                            }
                          })
                        })
                      }
                    })
                  }
                  .width('100%')
                  .height('100%')
                  .backgroundColor('#EFF1F4')
                  .sticky(StickyStyle.Header)
                  .scrollBar(BarState.Off)
                  // 获取联系人列表滑动位置的索引，并将索引通过selectedIndex同步给右侧字母导航
                  .onScrollIndex((start: number, end: number, center: number) => {
                    this.selectedIndex = start
                  })
                }
              }
              .tabBar(this.tabBuilder(1, $r('app.string.conversation_select_contact')))

              // 我的群聊
              TabContent() {
                if (this.viewModel.teamList.length <= 0) {
                  CommonEmptyResult({
                    tips: $r('app.string.no_team')
                  })
                } else {
                  List({ scroller: this.listScroller }) {
                    ForEach(this.viewModel.teamList, (item: ConversationSelectModel) => {
                      ListItem() {
                        Row() {
                          if (this.isMultiSelect) {
                            Image(item.isSelected ? $r('app.media.select_yes') : $r('app.media.select_no'))
                              .height(18)
                              .width(18)
                              .margin({
                                left: 20,
                                right: -10
                              })
                          }

                          Row() {
                            CommonAvatar({
                              item: new AvatarItem(item.avatar, NECommonUtils.shortName(item.name),
                                AvatarColorUntil.getBackgroundColorById(item.conversationId ?? ""))
                            })
                              .width(36)
                              .height(36)
                              .borderRadius(18)

                            Text(item.name)
                              .fontSize(14)
                              .fontColor("#333333")
                              .height(18)
                              .margin({ left: 12, right: 12 })
                              .layoutWeight(1)
                              .maxLines(1)
                              .textOverflow({ overflow: TextOverflow.Ellipsis })
                              .ellipsisMode(EllipsisMode.END)

                            if (item.memberCount > 0) {
                              Text(`(${item.memberCount})`)
                                .width(this.isMultiSelect ? 70 : 50)
                                .fontSize(14)
                                .fontColor("#333333")
                                .height(18)
                                .maxLines(1)
                                .textOverflow({ overflow: TextOverflow.Ellipsis })
                                .ellipsisMode(EllipsisMode.END)
                            }
                          }
                          .alignSelf(ItemAlign.Center)
                          .height(60)
                          .margin({ left: 20, right: 20 })
                        }
                      }
                      .width('100%')
                      .height(60)
                      .backgroundColor(Color.White)
                      .onClick(() => {
                        if (item.conversationId) {
                          // 单选
                          if (!this.isMultiSelect) {
                            this.selectedList = [item]
                            this.callback()
                            return
                          }

                          // 多选
                          if (item.isSelected) {
                            for (let index = 0; index < this.selectedList.length; index++) {
                              if (this.selectedList[index].conversationId === item.conversationId) {
                                this.selectedList.splice(index, 1)
                                item.isSelected = false
                              }
                            }
                          } else {
                            if (this.selectedList.length < this.selectLimit) {
                              this.selectedList.push(item)
                              item.isSelected = true
                            } else {
                              NECommonUtils.showToast($r('app.string.conversation_select_limit_tip', this.selectLimit))
                            }
                          }
                        }
                      })
                    })
                  }
                  .width('100%')
                  .height('100%')
                  .backgroundColor('#EFF1F4')
                  .scrollBar(BarState.Off)
                }
              }
              .tabBar(this.tabBuilder(2, $r('app.string.conversation_select_team')))
            }
            .vertical(false)
            .barMode(BarMode.Fixed)
            .barHeight(40)
            .onChange((index: number) => {
              // 变更时修改当前索引
              this.currentIndex = index;
            })
            .width('100%')
            .height('100%')
            .backgroundColor(Color.White)
            .margin({
              top: (this.isMultiSelect && this.selectedList.length > 0) ? 2 : 0
            })
          }
          .width('100%')
          .margin({ bottom: 56 + (this.selectedList.length > 0 ? 52 : 0) })
          .backgroundColor('#EFF1F4')
        }
        .alignContent(Alignment.Top)

        if (this.currentIndex === 1) {
          // 使用AlphabetIndexer组件实现右侧字母导航
          AlphabetIndexer({ arrayValue: this.viewModel.contactViewModel.initalList, selected: 0 })
            .color('#666666')
            .selectedColor(Color.White)
            .selectedBackgroundColor('#337EFF')
            .usingPopup(true)
            .popupPosition({ x: 30, y: (this.viewModel.contactViewModel.initalList.length * 16 - 48) / 2 })
            .margin({ right: 10 })
            .itemSize(16)
            .font({ size: 10 })// 指定字母导航的选择项为selectedIndex，完成跟联系人列表的同步
            .selected(this.selectedIndex)// 获取选中字母的索引值，通过listScroller控制列表滑动到对应索引位置
            .onSelect((index: number) => {
              this.listScroller.scrollToIndex(index)
            })
        }
      }
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.requestData()
    })
    .onDisAppear(() => {
      this.viewModel.onDestroy()
    })
  }
}