/*
 *  Copyright (c) 2022 NetEase, Inc. All rights reserved.
 *  Use of this source code is governed by a MIT license that can be
 *  found in the LICENSE file.
 */

import { Logger } from '@nimkit/common';
import { ChatKitClient, getMultiLineBody, getMultiLineTitle, IMKitConfigCenter, isMultiLineMessage } from '@nimkit/chatkit';
import { ChatBaseViewModel } from '../viewmodel/ChatBaseViewModel';
import { AvatarColorUntil, AvatarItem, CommonAvatar, CommonEmptyResult, CommonTextInput, NavigationBackBuilder, NECommonUtils, TailString } from '@nimkit/common';
import { EmojiParseType, NEEmojiManager, NEEmojiParseResult, NIMInputEmoticon } from '../manager/NEEmojiManager';
import { memberHistoryMessageContent } from '../view/MessageComponentBuilder';
import { DateUtil } from '@nimkit/common';
import { SearchFTSHistoryViewModel } from '../viewmodel/SearchFTSHistoryViewModel';
import { V2NIMConversationType, V2NIMMessageType } from '@nimsdk/base';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { CommonQuickSearchButton } from '../view/CommonQuickSearchButton';
import { ManagerSelectorParams, TeamMemberSelectorMode } from '@nimkit/chatkit';
import { TeamMemberMessageParams } from '../viewmodel/TeamMemberMessageViewModel';
import { ChatSearchImageMessageParams } from '../viewmodel/ChatSearchImageMessageViewModel';
import { ChatSearchVideoMessageParams } from '../viewmodel/ChatSearchVideoMessageViewModel';
import { ChatSearchFileMessageParams } from '../viewmodel/ChatSearchFileMessageViewModel';
import { ChatSearchDateMessageParams } from '../viewmodel/ChatSearchDateMessageViewModel';
import { SearchFTSHistory } from '../model/SearchFTSHistory';

// 跳转页面入口函数
@Builder
export function SearchFTSHistoryPageBuilder() {
  SearchFTSHistoryPage()
}

/**
 * 统一的全文搜索历史消息页面
 * 同时支持 P2P 和 Team 场景
 */
@ComponentV2
export struct SearchFTSHistoryPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local conversationId: string = ""
  @Local viewModel?: SearchFTSHistoryViewModel
  @Local isEmpty: boolean = false
  @Local searchText: string = ""
  @Local searchTextLen: number = 0
  @Local isLoading: boolean = false
  @Local isLoadingMore: boolean = false
  onSubmit = async (_enterKey: EnterKeyType, event: SubmitEvent) => {
    this.searchText = event.text
    this.searchTextLen = event.text.length

    if (ChatKitClient.connectBroken() && IMKitConfigCenter.enableCloudSearch) {
      NECommonUtils.showToast($r('app.string.chat_network_error_tips'), Alignment.Center)
      return
    }

    if (this.searchText.length > 0) {
      try {
        this.isLoading = true
        await this.viewModel?.searchHistoryMessages(event.text, true)
        this.isEmpty = (this.viewModel?.historyList.length ?? 0) <= 0
      } catch (err) {
        Logger.error('ChatKitUI', err)
        this.isEmpty = true
      } finally {
        this.isLoading = false
      }
    }
  }
  loadMoreMessages = async () => {
    if (this.isLoadingMore || !this.viewModel?.hasMore || this.searchText.length === 0) {
      return
    }

    if (ChatKitClient.connectBroken() && IMKitConfigCenter.enableCloudSearch) {
      NECommonUtils.showToast($r('app.string.chat_network_error_tips'), Alignment.Center)
      return
    }

    this.isLoadingMore = true
    try {
      await this.viewModel?.searchHistoryMessages(this.searchText, false)
    } catch (err) {
      Logger.error('ChatKitUI', '加载更多消息失败:', err)
    } finally {
      this.isLoadingMore = false
    }
  }
  onTextChange = (value: string) => {
    this.searchTextLen = value.length
    this.viewModel?.resetSearchResult()
    if (value.length === 0) {
      this.viewModel?.clearHistoryMessages()
      this.isEmpty = false
    }
  }

  requestData() {
    const param = this.pathStack.getParamByName("SearchFTSHistoryPage") as string[];
    if (param.length > 0) {
      this.conversationId = param[0];
    } else {
      this.pathStack.removeByName("SearchFTSHistoryPage")
      return
    }

    this.viewModel = new SearchFTSHistoryViewModel(this.conversationId)
  }

  /**
   * 是否是群聊会话
   */
  isTeamConversation(): boolean {
    return this.viewModel?.conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.search_chat_history'),
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        CommonTextInput({
          placeHolderText: $r('app.string.team_history_record_tip'),
          onSubmit: this.onSubmit.bind(this),
          onTextChange: this.onTextChange,
          keepEditableState: false
        })
          .margin({
            top: 16
          })

        // 快速搜索按钮区域
        Column() {
          Row() {
            Text($r('app.string.search_chat_history_quickly'))
              .fontColor('#999999')
              .fontSize(14)
              .margin({
                top: 26,
                bottom: 16,
              })
          }

          // 使用列表驱动渲染按钮
          this.QuickSearchButtonsBuilder()
        }
        .visibility(this.searchTextLen === 0 ? Visibility.Visible : Visibility.None)

        if (this.isEmpty) {
          CommonEmptyResult({
            emptyImage: $r('app.media.no_history'),
            tips: $r('app.string.team_history_record_empty_tip')
          })
            .margin({
              top: 74
            })
            .visibility(this.searchTextLen > 0 ? Visibility.Visible : Visibility.None)
        }

        // 消息列表
        Column() {
          List() {
            ForEach(this.viewModel?.historyList, (item: SearchFTSHistory) => {
              ListItem() {
                Column() {
                  // 时间（单独一行，居中显示）
                  Text(DateUtil.formatTimestamp(item.message.createTime, true))
                    .fontSize(12)
                    .fontColor('#B3B3B3')
                    .margin({ top: 6, bottom: 6 })

                  // 消息主体（头像 + 内容）
                  Row() {
                    // 头像（统一在左侧）
                    CommonAvatar({
                      item: new AvatarItem(item.getAvatar(),
                        TailString(item.getAvatarName()),
                        AvatarColorUntil.getBackgroundColorById(item.getAccId() ?? "")),
                      roundRadius: 21
                    })
                      .width(42)
                      .height(42)
                      .margin({ left: 16 })

                    Column() {
                      // 发送者昵称
                      Text(item.getNickname())
                        .fontSize(12)
                        .fontColor('#333333')
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })

                      // 消息内容：文本消息和换行消息使用自定义 emoji + 高亮渲染，其他类型使用 memberHistoryMessageContent
                      if (item.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
                        // 文本消息：使用 parseTextWithEmojiAndHighlight 解析 emoji 并高亮关键词
                        Row() {
                          Text() {
                            ForEach(parseTextWithEmojiAndHighlight(item.message.text ?? '', this.searchText.trim()),
                              (segment: EmojiTextSegment, index: number) => {
                                if (segment.emoji && segment.emoji.file) {
                                  // emoji 图片
                                  ImageSpan($rawfile(`emoji/${segment.emoji.file}`))
                                    .width(18)
                                    .height(18)
                                    .verticalAlign(ImageSpanAlignment.CENTER)
                                } else if (segment.text) {
                                  // 文本（可能高亮）
                                  Span(segment.text)
                                    .fontSize($r('app.float.chat_message_text_font_size'))
                                    .fontColor(segment.isHighlight ? '#337EFF' : $r('app.color.color_chat_title'))
                                }
                              }, (segment: EmojiTextSegment, index: number) => `${index}-${segment.text ?? segment.emoji?.tag ?? ''}`)
                          }
                          .constraintSize({ maxWidth: '100%' })
                        }
                        .backgroundColor($r('app.color.color_chat_receive_message_bg'))
                        .borderRadius({
                          topLeft: 0,
                          topRight: 8,
                          bottomLeft: 8,
                          bottomRight: 8
                        })
                        .padding({
                          left: 14,
                          right: 14,
                          top: 10,
                          bottom: 10
                        })
                        .margin({ top: 6 })
                      } else if (isMultiLineMessage(item.message)) {
                        // 换行消息：标题+正文，支持关键词高亮
                        Column() {
                          // 标题（如果有）
                          if (getMultiLineTitle(item.message).length > 0) {
                            Text() {
                              ForEach(parseTextWithEmojiAndHighlight(getMultiLineTitle(item.message), this.searchText.trim()),
                                (segment: EmojiTextSegment, index: number) => {
                                  if (segment.emoji && segment.emoji.file) {
                                    ImageSpan($rawfile(`emoji/${segment.emoji.file}`))
                                      .width(18)
                                      .height(18)
                                      .verticalAlign(ImageSpanAlignment.CENTER)
                                  } else if (segment.text) {
                                    Span(segment.text)
                                      .fontSize($r('app.float.chat_message_text_font_size'))
                                      .fontWeight(FontWeight.Bold)
                                      .fontColor(segment.isHighlight ? '#337EFF' : $r('app.color.color_chat_title'))
                                  }
                                }, (segment: EmojiTextSegment, index: number) => `title-${index}-${segment.text ?? segment.emoji?.tag ?? ''}`)
                            }
                            .constraintSize({ maxWidth: '100%' })
                            .margin({ bottom: 4 })
                          }
                          // 正文（如果有）
                          if (getMultiLineBody(item.message).length > 0) {
                            Text() {
                              ForEach(parseTextWithEmojiAndHighlight(getMultiLineBody(item.message), this.searchText.trim()),
                                (segment: EmojiTextSegment, index: number) => {
                                  if (segment.emoji && segment.emoji.file) {
                                    ImageSpan($rawfile(`emoji/${segment.emoji.file}`))
                                      .width(18)
                                      .height(18)
                                      .verticalAlign(ImageSpanAlignment.CENTER)
                                  } else if (segment.text) {
                                    Span(segment.text)
                                      .fontSize($r('app.float.chat_message_text_font_size'))
                                      .fontColor(segment.isHighlight ? '#337EFF' : $r('app.color.color_chat_title'))
                                  }
                                }, (segment: EmojiTextSegment, index: number) => `body-${index}-${segment.text ?? segment.emoji?.tag ?? ''}`)
                            }
                            .constraintSize({ maxWidth: '100%' })
                          }
                        }
                        .alignItems(HorizontalAlign.Start)
                        .backgroundColor($r('app.color.color_chat_receive_message_bg'))
                        .borderRadius({
                          topLeft: 0,
                          topRight: 8,
                          bottomLeft: 8,
                          bottomRight: 8
                        })
                        .padding({
                          left: 14,
                          right: 14,
                          top: 10,
                          bottom: 10
                        })
                        .margin({ top: 6 })
                      } else {
                        // 非文本消息：使用 memberHistoryMessageContent 展示
                        memberHistoryMessageContent({
                          message: new NIMMessageInfo(item.message),
                          onMessageClick: undefined
                        })
                          .backgroundColor($r('app.color.color_chat_receive_message_bg'))
                          .borderRadius({
                            topLeft: 0,
                            topRight: 8,
                            bottomLeft: 8,
                            bottomRight: 8
                          })
                          .margin({ top: 6 })
                      }
                    }
                    .layoutWeight(1)
                    .margin({ left: 10, right: 16 })
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Top)
                }
                .width('100%')
                .padding({ bottom: 12 })
                .backgroundColor(Color.White)
                .alignItems(HorizontalAlign.Center)
              }
              .onClick(() => {
                if (ChatBaseViewModel.currentViewModel) {
                  const msgInfo: NIMMessageInfo = new NIMMessageInfo(item.message)
                  ChatBaseViewModel.currentViewModel.setAnchorMessage(msgInfo)
                }
                if (item.message.conversationType == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
                  this.pathStack.popToName('ChatP2PPage')
                } else if (item.message.conversationType == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
                  this.pathStack.popToName('ChatTeamPage')
                }
              })
            }, (item: SearchFTSHistory) => item.message.messageClientId)

            if (this.isLoading) {
              ListItem() {
                Row() {
                  Row() {
                    LoadingProgress()
                      .width(20)
                      .height(20)
                      .margin({ right: 8 })
                      .color('#666666')
                    Text($r('app.string.search_message_loading'))
                      .fontSize(14)
                      .fontColor('#666666')
                  }
                  .height(40)
                  .padding({
                    left: 20,
                    right: 20
                  })
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor('#F5F5F5')
                  .borderRadius(20)
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .margin({
                  top: 10,
                  bottom: 10
                })
              }
              .backgroundColor(Color.Transparent)
            }

            // 加载更多按钮
            if (this.viewModel?.hasMore && this.searchTextLen > 0 && !this.isEmpty) {
              ListItem() {
                Divider()
                  .strokeWidth(1)
                  .color("#EEEEEE")
                  .margin({
                    left: 20,
                    right: 20,
                    bottom: 20
                  })
              }

              ListItem() {
                Row() {
                  Row() {
                    if (this.isLoadingMore) {
                      LoadingProgress()
                        .width(20)
                        .height(20)
                        .margin({ right: 8 })
                        .color('#666666')
                      Text($r('app.string.search_message_loading'))
                        .fontSize(14)
                        .fontColor('#666666')
                    } else {
                      Text($r('app.string.search_message_load_more'))
                        .fontSize(14)
                        .fontColor('#666666')
                    }
                  }
                  .height(40)
                  .padding({
                    left: 20,
                    right: 20
                  })
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor('#F5F5F5')
                  .borderRadius(20)
                  .onClick(() => {
                    if (!this.isLoadingMore) {
                      this.loadMoreMessages()
                    }
                  })
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .margin({
                  top: 10,
                  bottom: 10
                })
              }
              .backgroundColor(Color.Transparent)
            } else if (!this.viewModel?.hasMore && this.searchTextLen > 0 && !this.isEmpty &&
              (this.viewModel?.historyList?.length ?? 0) > 0) {
              ListItem() {
                Row() {
                  Text($r('app.string.chat_message_no_more_data'))
                    .fontSize(14)
                    .fontColor('#999999')
                }
                .width('100%')
                .height(50)
                .justifyContent(FlexAlign.Center)
              }
              .backgroundColor(Color.Transparent)
            }

            // 添加空白区域
            ListItem() {
              Column()
                .height(200)
                .width('100%')
            }
            .backgroundColor(Color.Transparent)
          }
          .onReachEnd(() => {
            if (this.viewModel?.hasMore && this.searchTextLen > 0 && !this.isEmpty && !this.isLoadingMore) {
              this.loadMoreMessages()
            }
          })
        }
        .layoutWeight(1)
        .visibility(this.searchTextLen > 0 && !this.isEmpty ? Visibility.Visible : Visibility.None)
      }
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.requestData()
    })
  }

  @Monitor("viewModel.revokeAndeDeleteMission")
  onRevokeAndeDeleteMissionChanged() {
    if (this.viewModel?.revokeAndeDeleteMission) {
      this.isEmpty = (this.viewModel?.historyList.length ?? 0) <= 0
    }
    this.viewModel?.resetRevokeAndeDeleteMission()
  }

  /**
   * 获取快速搜索按钮配置列表
   * P2P 顺序: 图片、视频、日期、文件
   * Team 顺序: 群成员、图片、视频、日期、文件
   */
  getQuickSearchButtons(): QuickSearchButtonConfig[] {
    const buttons: QuickSearchButtonConfig[] = []

    if (this.isTeamConversation()) {
      // Team: 群成员、图片、视频、日期、文件
      buttons.push({
        icon: $r('app.media.icon_search_team_member'),
        text: $r('app.string.search_by_team_member'),
        onClickHandler: (): void => this.onTeamMemberSearchClick()
      })
    }

    // 图片
    buttons.push({
      icon: $r('app.media.icon_search_photo'),
      text: $r('app.string.search_by_photo'),
      onClickHandler: (): void => this.onPhotoSearchClick()
    })

    // 视频
    buttons.push({
      icon: $r('app.media.icon_search_video'),
      text: $r('app.string.search_by_video'),
      onClickHandler: (): void => this.onVideoSearchClick()
    })

    // 日期
    buttons.push({
      icon: $r('app.media.icon_search_date'),
      text: $r('app.string.search_by_date'),
      onClickHandler: (): void => this.onDateSearchClick()
    })

    // 文件
    buttons.push({
      icon: $r('app.media.icon_search_file'),
      text: $r('app.string.search_by_file'),
      onClickHandler: (): void => this.onFileSearchClick()
    })

    return buttons
  }

  // 群成员搜索点击
  onTeamMemberSearchClick() {
    let params: ManagerSelectorParams = {
      teamId: this.viewModel?.teamId ?? '',
      selectLimit: 1,
      mode: TeamMemberSelectorMode.FTS_SEARCH
    }
    this.pathStack.pushPath({
      name: 'TeamMemberSelectorPage',
      param: params,
      onPop: (popInfo: PopInfo) => {
        let selectList = popInfo.result as string[]
        if (selectList.length > 0) {
          let selectMemberInfo: TeamMemberMessageParams = {
            conversationId: this.conversationId,
            senderId: selectList[0]
          }
          this.pathStack.pushPath({
            name: 'TeamMemberMessagePage',
            param: selectMemberInfo
          })
        }
      }
    })
  }

  // 图片搜索点击
  onPhotoSearchClick() {
    let imageParams: ChatSearchImageMessageParams = {
      conversationId: this.conversationId,
    }
    this.pathStack.pushPath({
      name: 'ChatSearchImageMessagePage',
      param: imageParams
    })
  }

  // 视频搜索点击
  onVideoSearchClick() {
    let videoParams: ChatSearchVideoMessageParams = {
      conversationId: this.conversationId,
    }
    this.pathStack.pushPath({
      name: 'ChatSearchVideoMessagePage',
      param: videoParams
    })
  }

  // 日期搜索点击
  onDateSearchClick() {
    let dateParams: ChatSearchDateMessageParams = {
      conversationId: this.conversationId,
    }
    this.pathStack.pushPath({
      name: 'ChatSearchDateMessagePage',
      param: dateParams
    })
  }

  // 文件搜索点击
  onFileSearchClick() {
    let fileParams: ChatSearchFileMessageParams = {
      conversationId: this.conversationId,
    }
    this.pathStack.pushPath({
      name: 'ChatSearchFileMessagePage',
      param: fileParams
    })
  }

  /**
   * 快速搜索按钮构建器
   * P2P: 一行四个
   * Team: 第一行四个，第二行一个 + 三个占位
   */
  @Builder
  QuickSearchButtonsBuilder() {
    Column() {
      // 获取按钮配置列表
      ForEach(this.getButtonRows(), (row: QuickSearchButtonConfig[], rowIndex: number) => {
        Row() {
          ForEach(row, (config: QuickSearchButtonConfig, index: number) => {
            if (config.visible === Visibility.Hidden) {
              // 占位按钮
              CommonQuickSearchButton({
                icon: 'no',
                text: 'no',
                visible: Visibility.Hidden
              })
            } else {
              CommonQuickSearchButton({
                icon: config.icon,
                text: config.text,
                onClickHandler: config.onClickHandler,
                visible: config.visible
              })
            }
          }, (config: QuickSearchButtonConfig, index: number) => `${rowIndex}-${index}`)
        }
        .margin({
          left: '4%',
          right: '4%'
        })
      }, (row: QuickSearchButtonConfig[], index: number) => `row-${index}`)
    }
  }

  /**
   * 将按钮列表分成多行
   * P2P: 4个按钮一行
   * Team: 第一行4个，第二行1个 + 3个占位
   */
  getButtonRows(): QuickSearchButtonConfig[][] {
    const buttons = this.getQuickSearchButtons()
    const rows: QuickSearchButtonConfig[][] = []
    const buttonsPerRow = 4

    // 第一行
    const firstRow = buttons.slice(0, buttonsPerRow)
    rows.push(firstRow)

    // 如果有更多按钮（Team 场景），创建第二行
    if (buttons.length > buttonsPerRow) {
      const secondRowButtons = buttons.slice(buttonsPerRow)
      // 补齐占位按钮
      while (secondRowButtons.length < buttonsPerRow) {
        secondRowButtons.push({
          icon: 'no',
          text: 'no',
          visible: Visibility.Hidden
        })
      }
      rows.push(secondRowButtons)
    }

    return rows
  }
}

/**
 * 快速搜索按钮配置
 */
interface QuickSearchButtonConfig {
  icon: ResourceStr
  text: ResourceStr
  onClickHandler?: () => void
  visible?: Visibility
}

/**
 * emoji + 高亮文本片段
 */
interface EmojiTextSegment {
  text?: string
  emoji?: NIMInputEmoticon
  isHighlight: boolean
}

/**
 * 解析文本为 emoji + 高亮片段数组
 * @param text 原始文本
 * @param searchText 搜索关键字
 * @returns 片段数组
 */
function parseTextWithEmojiAndHighlight(text: string, searchText: string): EmojiTextSegment[] {
  const result: EmojiTextSegment[] = []

  // 第一步：使用 NEEmojiManager 解析 emoji
  const emojiParsed: NEEmojiParseResult[] = NEEmojiManager.instance.parseEmojiText(text)

  // 第二步：对每个片段进行关键字高亮处理
  const searchLower = searchText.toLowerCase()

  for (const item of emojiParsed) {
    if (item.type === EmojiParseType.emoji && item.emoji) {
      // emoji 片段，直接添加
      result.push({
        emoji: item.emoji,
        isHighlight: false
      })
    } else if (item.text) {
      // 文本片段，需要进行关键字匹配和分割
      const textLower = item.text.toLowerCase()
      let lastIndex = 0
      let searchIndex = textLower.indexOf(searchLower)

      while (searchIndex >= 0) {
        // 添加高亮前的普通文本
        if (searchIndex > lastIndex) {
          result.push({
            text: item.text.substring(lastIndex, searchIndex),
            isHighlight: false
          })
        }

        // 添加高亮文本（保持原始大小写）
        result.push({
          text: item.text.substring(searchIndex, searchIndex + searchText.length),
          isHighlight: true
        })

        lastIndex = searchIndex + searchText.length
        searchIndex = textLower.indexOf(searchLower, lastIndex)
      }

      // 添加剩余的普通文本
      if (lastIndex < item.text.length) {
        result.push({
          text: item.text.substring(lastIndex),
          isHighlight: false
        })
      }
    }
  }

  return result
}
