/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ViewItemSwitch } from '@nimkit/common';
import {
  CommonConstants,
  NavigationBackBuilder,
  ViewItemBuilder
} from '@nimkit/common';
import { IMKitConfigCenter } from '@nimkit/chatkit';
import { ChatBaseViewModel, ChatKitConfig } from '@nimkit/chatkit_ui';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { resolveReadMessageEnabled, resolveTeamJoinAgreeModeEnabled } from '../../manager/GlobalConfigStorage';

// 跳转页面入口函数
@Builder
function GlobalConfigPageBuilder() {
  GlobalConfigPage()
}

@ComponentV2
export struct GlobalConfigPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local aiStreamEnable: boolean = AppStorage.get(CommonConstants.KEY_SETTING_AI_STREAM) ?? true
  @Local richTextEnable: boolean = AppStorage.get(CommonConstants.KEY_SETTING_RICH_TEXT_MESSAGE) ?? true
  @Local reactionEnable: boolean = AppStorage.get(CommonConstants.KEY_SETTING_REACTION_ENABLE) ?? true
  @Local teamEnable: boolean = AppStorage.get(CommonConstants.KEY_SETTING_TEAM_ENABLE) ?? true
  @Local readMessageEnable: boolean = true
  @Local lastReadPositionEnable: boolean = AppStorage.get(CommonConstants.KEY_SETTING_LAST_READ_POSITION_ENABLE) ?? true
  @Local teamModeEnable: boolean = true
  @Local collectionEnable: boolean = AppStorage.get(CommonConstants.KEY_SETTING_COLLECTION_ENABLE) ?? true
  @Local pinEnable: boolean = AppStorage.get(CommonConstants.KEY_SETTING_PIN_ENABLE) ?? true
  @Local topMessageEnable: boolean = AppStorage.get(CommonConstants.KEY_SETTING_TOP_MESSAGE) ?? true
  @Local onlyFriendCallEnable: boolean = AppStorage.get(CommonConstants.KEY_SETTING_ONLY_FRIEND_CALL) ?? true
  @Local typingStatusEnable: boolean = AppStorage.get(CommonConstants.KEY_SETTING_TYPING_STATUS) ?? true
  @Local antiSpamTipMessage: boolean = AppStorage.get(CommonConstants.KEY_SETTING_ANTISPAM_TIP_MESSAGE) ?? true
  @Local cloudSearch: boolean = AppStorage.get(CommonConstants.KEY_SETTING_CLOUD_SEARCH) ?? false
  @Local teamManagerMaxCount: number = AppStorage.get(CommonConstants.KEY_SETTING_TEAM_MANAGER_MAX_COUNT) ?? 10
  @Local switchItems: ViewItemSwitch[] = []
  dataPreferences: preferences.Preferences | undefined

  aboutToAppear(): void {
    let options: preferences.Options = { name: 'imkit_data' };
    this.dataPreferences = preferences.getPreferencesSync(getContext(this), options);
    this.teamModeEnable = resolveTeamJoinAgreeModeEnabled(
      this.dataPreferences?.getSync(CommonConstants.KEY_SETTING_TEAM_JOIN_AGREE_MODE, undefined) as boolean | undefined
    )
    IMKitConfigCenter.enableTeamJoinAgreeModelAuth = this.teamModeEnable

    this.reactionEnable = AppStorage.get(CommonConstants.KEY_SETTING_REACTION_ENABLE) ?? true
    ChatKitConfig.enableEmojiReaction = this.reactionEnable
    this.lastReadPositionEnable = AppStorage.get(CommonConstants.KEY_SETTING_LAST_READ_POSITION_ENABLE) ?? true
    ChatKitConfig.enableLastReadPosition = this.lastReadPositionEnable

    this.readMessageEnable = resolveReadMessageEnabled(
      this.dataPreferences?.getSync(CommonConstants.KEY_SETTING_READ_MESSAGE, undefined) as boolean | undefined,
      AppStorage.get<boolean>(CommonConstants.KEY_SETTING_MESSAGE_READ_OR)
    )
    IMKitConfigCenter.enableReadMessage = this.readMessageEnable
    ChatKitConfig.messageReadState = this.readMessageEnable

    this.switchItems = [
      {
        title: $r('app.string.mine_setting_ai_stream'),
        itemHeight: 48,
        isOpen: this.aiStreamEnable,
        switchChange: (isOpen: boolean) => {
          AppStorage.set(CommonConstants.KEY_SETTING_AI_STREAM, isOpen)
          IMKitConfigCenter.enableAIStream = isOpen
        }
      },
      {
        title: $r('app.string.mine_setting_rich_text'),
        itemHeight: 48,
        isOpen: this.richTextEnable,
        switchChange: (isOpen: boolean) => {
          AppStorage.set(CommonConstants.KEY_SETTING_RICH_TEXT_MESSAGE, isOpen)
          IMKitConfigCenter.enableRichTextMessage = isOpen
        }
      },
      {
        title: $r('app.string.mine_setting_team_enable'),
        itemHeight: 48,
        isOpen: this.teamEnable,
        switchChange: (isOpen: boolean) => {
          AppStorage.set(CommonConstants.KEY_SETTING_TEAM_ENABLE, isOpen)
          IMKitConfigCenter.enableTeam = isOpen
        }
      },
      {
        title: $r('app.string.mine_setting_team_mode'),
        itemHeight: 48,
        isOpen: this.teamModeEnable,
        switchChange: this.teamModeEnableChange
      },
      {
        title: $r('app.string.mine_setting_collection'),
        itemHeight: 48,
        isOpen: this.collectionEnable,
        switchChange: (isOpen: boolean) => {
          AppStorage.set(CommonConstants.KEY_SETTING_COLLECTION_ENABLE, isOpen)
          IMKitConfigCenter.enableCollection = isOpen
        }
      },
      {
        title: $r('app.string.mine_setting_pin'),
        itemHeight: 48,
        isOpen: this.pinEnable,
        switchChange: (isOpen: boolean) => {
          AppStorage.set(CommonConstants.KEY_SETTING_PIN_ENABLE, isOpen)
          IMKitConfigCenter.enablePin = isOpen
        }
      },
      {
        title: $r('app.string.mine_setting_top_message'),
        itemHeight: 48,
        isOpen: this.topMessageEnable,
        switchChange: (isOpen: boolean) => {
          AppStorage.set(CommonConstants.KEY_SETTING_TOP_MESSAGE, isOpen)
          IMKitConfigCenter.enableTopMessage = isOpen
        }
      },
      {
        title: $r('app.string.mine_setting_only_friend_call'),
        itemHeight: 48,
        isOpen: this.onlyFriendCallEnable,
        switchChange: (isOpen: boolean) => {
          AppStorage.set(CommonConstants.KEY_SETTING_ONLY_FRIEND_CALL, isOpen)
          IMKitConfigCenter.enableOnlyFriendCall = isOpen
        }
      },
      {
        title: $r('app.string.mine_setting_typing_status'),
        itemHeight: 48,
        isOpen: this.typingStatusEnable,
        switchChange: (isOpen: boolean) => {
          AppStorage.set(CommonConstants.KEY_SETTING_TYPING_STATUS, isOpen)
          IMKitConfigCenter.enableTypingStatus = isOpen
        }
      },
      {
        title: $r('app.string.mine_setting_read_message'),
        itemHeight: 48,
        isOpen: this.readMessageEnable,
        switchChange: (isOpen: boolean) => {
          this.readMessageEnableChange(isOpen)
        }
      },
      {
        title: $r('app.string.mine_setting_antispam_tip_message'),
        itemHeight: 48,
        isOpen: this.antiSpamTipMessage,
        switchChange: (isOpen: boolean) => {
          AppStorage.set(CommonConstants.KEY_SETTING_ANTISPAM_TIP_MESSAGE, isOpen)
          IMKitConfigCenter.enableAntiSpamTipMessage = isOpen
        }
      },
      {
        title: $r('app.string.mine_setting_cloud_search'),
        itemHeight: 48,
        isOpen: this.cloudSearch,
        switchChange: (isOpen: boolean) => {
          AppStorage.set(CommonConstants.KEY_SETTING_CLOUD_SEARCH, isOpen)
          IMKitConfigCenter.enableCloudSearch = isOpen
        }
      },
      {
        title: $r('app.string.mine_setting_last_read_position'),
        itemHeight: 48,
        isOpen: this.lastReadPositionEnable,
        switchChange: (isOpen: boolean) => {
          this.lastReadPositionEnable = isOpen
          AppStorage.set(CommonConstants.KEY_SETTING_LAST_READ_POSITION_ENABLE, isOpen)
          ChatKitConfig.enableLastReadPosition = isOpen
          ChatBaseViewModel.currentViewModel?.refreshLastReadPositionState()
        }
      },
      {
        title: $r('app.string.mine_setting_reaction'),
        itemHeight: 48,
        isOpen: this.reactionEnable,
        switchChange: (isOpen: boolean) => {
          this.reactionEnable = isOpen
          AppStorage.set(CommonConstants.KEY_SETTING_REACTION_ENABLE, isOpen)
          ChatKitConfig.enableEmojiReaction = isOpen
          ChatBaseViewModel.currentViewModel?.refreshMessageReactionState()
        }
      },
    ]
  }

  readMessageEnableChange = (isOpen: boolean) => {
    this.dataPreferences?.putSync(CommonConstants.KEY_SETTING_READ_MESSAGE, isOpen)
    this.dataPreferences?.flush((err: BusinessError) => {
      if (err) {
        console.error("Failed to flush. code =" + err.code + ", message =" + err.message);
        return;
      }
    })
    AppStorage.set(CommonConstants.KEY_SETTING_MESSAGE_READ_OR, isOpen)
    IMKitConfigCenter.enableReadMessage = isOpen
    ChatKitConfig.messageReadState = isOpen
  }

  teamModeEnableChange = (isOpen: boolean) => {
    this.dataPreferences?.putSync(CommonConstants.KEY_SETTING_TEAM_JOIN_AGREE_MODE, isOpen)
    this.dataPreferences?.flush((err: BusinessError) => {
      if (err) {
        console.error("Failed to flush. code =" + err.code + ", message =" + err.message);
        return;
      }
    })
    IMKitConfigCenter.enableTeamJoinAgreeModelAuth = isOpen
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.mine_setting_global_config'),
          backgroundColor: '#EFF1F4',
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        Scroll() {
          Column({ space: 12 }) {
            // Toggle 开关列表 + 群管理员数量输入（同一组）
            List() {
              ForEach(this.switchItems, (item: ViewItemSwitch) => {
                ListItem() {
                  ViewItemBuilder(item)
                }
                .width('100%')
                .height(item.itemHeight)
                .backgroundColor(item.backgroundColor ?? Color.White)
              })

              // 群管理员数量上限（垂直布局，与 Android 对齐）
              ListItem() {
                Column() {
                  Text($r('app.string.mine_setting_team_manager_max_count'))
                    .fontSize(16)
                    .fontColor('#333333')
                    .width('100%')
                    .height(46)
                    .padding({ left: 16 })
                    .textAlign(TextAlign.Start)

                  TextInput({ text: this.teamManagerMaxCount.toString() })
                    .width(96)
                    .height(40)
                    .fontSize(16)
                    .fontColor('#333333')
                    .margin({ left: 20 })
                    .backgroundColor('#F5F5F5')
                    .borderRadius(4)
                    .onChange((value: string) => {
                      let num = parseInt(value)
                      if (!isNaN(num)) {
                        this.teamManagerMaxCount = num
                        AppStorage.set(CommonConstants.KEY_SETTING_TEAM_MANAGER_MAX_COUNT, num)
                        IMKitConfigCenter.teamManagerMaxCount = num
                      }
                    })
                }
                .width('100%')
                .height(96)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .backgroundColor(Color.White)
            }
            .borderRadius(8)
            .backgroundColor(Color.White)
            .margin({ left: 20, right: 20, top: 0 })
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .hideTitleBar(true)
    .backgroundColor('#EFF1F4')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
  }
}
