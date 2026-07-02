/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import { ErrorUtils, StorageRepo, UserAIBotManager } from '@nimkit/chatkit';
import {
  AvatarColorUntil,
  AvatarItem,
  ChooseAvatarDialog,
  CommonAvatar,
  NavigationBackBuilder,
  NECommonUtils,
  TailString
} from '@nimkit/common';
import { V2NIMUpdateUserAIBotParams, V2NIMUserAIBot } from '@nimsdk/base';
import fs from '@ohos.file.fs';
import { EditBotNameParam } from './EditBotNamePage';

@ComponentV2
export struct EditBotPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local accid: string = ''
  @Local botName: string = ''
  @Local avatarUrl: string = ''
  @Local avatarLocalPath: string = ''
  @Local isSubmitting: boolean = false
  // 记录原始值，用于判断是否有修改
  private originalName: string = ''
  private originalIcon: string = ''

  onImageChosen = async (filePath: string) => {
    if (ErrorUtils.checkNetworkAndToast()) {
      try {
        const cacheDir = getContext(this).getApplicationContext().cacheDir
        const filePathSplit = filePath.split('/')
        const dir = cacheDir + '/' + filePathSplit[filePathSplit.length - 1]
        const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY)
        fs.copyFileSync(file.fd, dir)
        const task = StorageRepo.createUploadFileTask({
          filePath: dir,
          sceneName: 'nim_default_profile_icon'
        })
        if (task) {
          const url = await StorageRepo.uploadFile(task, () => {})
          if (url) {
            this.avatarUrl = url
            this.avatarLocalPath = filePath
          }
        }
      } catch (err) {
        Logger.error('ContactKit', 'upload avatar error: ' + JSON.stringify(err))
      }
    }
  }

  chooseAvatarDialog: CustomDialogController = new CustomDialogController({
    builder: ChooseAvatarDialog({ onImageChosen: this.onImageChosen }),
    cornerRadius: 0,
    alignment: DialogAlignment.Bottom,
    backgroundColor: Color.Transparent,
    backgroundBlurStyle: BlurStyle.NONE,
    height: 140,
  })

  private canSubmit(): boolean {
    return this.botName.trim().length > 0 && !this.isSubmitting
  }

  private hasChanged(): boolean {
    return this.botName.trim() !== this.originalName || this.avatarUrl !== this.originalIcon
  }

  private async doSave(): Promise<void> {
    if (!this.canSubmit()) return
    if (!ErrorUtils.checkNetworkAndToast()) return
    this.isSubmitting = true
    try {
      const params: V2NIMUpdateUserAIBotParams = {
        accid: this.accid,
        name: this.botName.trim(),
        icon: this.avatarUrl.length > 0 ? this.avatarUrl : undefined
      }
      Logger.info('ContactKit', '[EditBotPage] doSave start, accid=' + this.accid + ', name=' + this.botName.trim() + ', icon=' + (this.avatarUrl.length > 0 ? 'has' : 'empty'))
      await UserAIBotManager.updateUserAIBot(params)
      Logger.info('ContactKit', '[EditBotPage] doSave updateUserAIBot success')
      NECommonUtils.showToast($r('app.string.bot_update_success'))
      // 把更新后的 name 和 icon 带回去，避免依赖列表接口缓存
      const result: Record<string, string> = {
        'accid': this.accid,
        'name': this.botName.trim(),
        'icon': this.avatarUrl
      }
      Logger.info('ContactKit', '[EditBotPage] doSave pop with result, name=' + result['name'])
      this.pathStack.pop(result)
    } catch (err) {
      Logger.error('ContactKit', '[EditBotPage] doSave updateUserAIBot error: ' + JSON.stringify(err))
      NECommonUtils.showToast($r('app.string.bot_create_fail'))
    } finally {
      this.isSubmitting = false
    }
  }

  build() {
    NavDestination() {
      Column() {
        // 顶部导航
        NavigationBackBuilder({
          title: $r('app.string.bot_edit_title'),
          showDivideLine: true,
          leftButtonAction: () => {
            if (this.hasChanged()) {
              this.doSave()
            } else {
              this.pathStack.pop()
            }
          },
          rightButtonTitle: $r('app.string.common_save'),
          rightButtonColor: this.canSubmit() ? '#337EFF' : '#CCCCCC',
          rightButtonAction: () => {
            this.doSave()
          }
        })

        // 设置列表卡片
        List() {
          // 头像行（总高度 = 56 + 1 + 56 = 113）
          ListItem() {
            Row() {
              Text($r('app.string.bot_avatar'))
                .fontSize(16)
                .fontColor('#333333')
                .layoutWeight(1)

              CommonAvatar({
                item: new AvatarItem(
                  this.avatarLocalPath.length > 0 ? this.avatarLocalPath
                    : (this.avatarUrl.length > 0 ? this.avatarUrl : undefined),
                          TailString(this.botName.length > 0 ? this.botName : '?'),
                  AvatarColorUntil.getBackgroundColorById(this.accid)
                ),
                roundRadius: 18,
                textSize: 14
              })
                .width(36)
                .height(36)

              Image($r('app.media.arrow_right'))
                .width(16)
                .height(16)
                .margin({ left: 8 })
                .fillColor('#C0C0C0')
            }
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              this.chooseAvatarDialog.open()
            })
          }
          .backgroundColor(Color.White)

          // 分割线
          ListItem() {
            Divider()
              .strokeWidth(0.5)
              .color('#F0F0F0')
              .margin({ left: 16 })
          }
          .backgroundColor(Color.White)

          // 昵称行
          ListItem() {
            Row() {
              Text($r('app.string.bot_name'))
                .fontSize(16)
                .fontColor('#333333')
                .layoutWeight(1)

              Text(this.botName.length > 0 ? this.botName : '')
                .fontSize(14)
                .fontColor('#A6ADB6')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .constraintSize({ maxWidth: 160 })

              Image($r('app.media.arrow_right'))
                .width(16)
                .height(16)
                .margin({ left: 8 })
                .fillColor('#C0C0C0')
            }
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              this.pathStack.pushPath({
                name: 'EditBotNamePage',
                param: new EditBotNameParam(this.accid, this.botName, this.avatarUrl),
                onPop: (popInfo) => {
                  const result = popInfo.result as Record<string, string> | undefined
                  if (result && result['name']) {
                    // EditBotNamePage 已调用过 37-4 更新接口，直接把 result 继续往上传给 BotInfoPage
                    this.pathStack.pop(result)
                  }
                }
              })
            })
          }
          .backgroundColor(Color.White)
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      const param = this.pathStack.getParamByName('EditBotPage')[0] as V2NIMUserAIBot | string
      if (typeof param === 'string') {
        // 兼容旧的 accid 字符串方式
        this.accid = param
        UserAIBotManager.getUserAIBot({ accid: this.accid }).then((bot) => {
          if (bot) {
            this.botName = bot.name ?? ''
            this.avatarUrl = bot.icon ?? ''
          }
        }).catch(() => {})
      } else {
        // 直接接收 bot 对象（从 BotInfoPage 传入）
        const bot = param as V2NIMUserAIBot
        this.accid = bot.accid ?? ''
        this.botName = bot.name ?? ''
        this.avatarUrl = bot.icon ?? ''
        UserAIBotManager.mergeLocalUserAIBot(bot)
      }
      this.originalName = this.botName
      this.originalIcon = this.avatarUrl
    })
    .onBackPressed(() => {
      if (this.hasChanged()) {
        this.doSave()
      } else {
        this.pathStack.pop()
      }
      return true
    })
  }
}

@Builder
export function EditBotPageBuilder() {
  EditBotPage()
}
