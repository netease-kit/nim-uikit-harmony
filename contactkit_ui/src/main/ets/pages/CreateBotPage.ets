/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ErrorUtils, StorageRepo, UserAIBotRepo } from '@nimkit/chatkit';
import {
  AvatarColorUntil,
  AvatarItem,
  ChooseAvatarDialog,
  CommonAvatar,
  NavigationBackBuilder,
  NECommonUtils,
  TailString
} from '@nimkit/common';
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';
import { EditBotNameParam } from './EditBotNamePage';
import { V2NIMUserAIBot } from '@nimsdk/base';

@ComponentV2
export struct CreateBotPage {
  pathStack: NavPathStack = new NavPathStack()
  // bindQrcode: 从 BindBotPage 传入，创建后自动绑定
  @Local bindQrcode: string = ''
  @Local botName: string = ''
  @Local avatarUrl: string = ''
  @Local avatarLocalPath: string = ''
  @Local isSubmitting: boolean = false
  // 生成默认 accid，用于头像颜色和昵称编辑页的接口调用
  private accid: string = ''

  async aboutToAppear(): Promise<void> {
    // 生成 accid
    const prefix = 'Bot_'
    const uuid = util.generateRandomUUID(false).replace(/-/g, '')
    const maxSuffixLen = 32 - prefix.length
    this.accid = prefix + uuid.substring(0, maxSuffixLen)

    // 拉取当前机器人列表，找 Bot_X 最大序号，生成默认昵称 Bot_(max+1)
    try {
      const result = await UserAIBotRepo.getUserAIBotList({ limit: 100 })
      const bots = result?.bots ?? []
      let maxIndex = 0
      for (const bot of bots) {
        const name = bot.name ?? ''
        const match = name.match(/^Bot_(\d+)$/)
        if (match) {
          const idx = parseInt(match[1])
          if (idx > maxIndex) {
            maxIndex = idx
          }
        }
      }
      this.botName = 'Bot_' + (maxIndex + 1)
    } catch {
      this.botName = 'Bot_1'
    }
  }

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
        console.error('upload avatar error: ' + JSON.stringify(err))
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

  private async doCreate(): Promise<void> {
    if (!this.canSubmit()) {
      return
    }
    if (!ErrorUtils.checkNetworkAndToast()) {
      return
    }
    this.isSubmitting = true
    try {
      await UserAIBotRepo.createUserAIBot({
        accid: this.accid,
        name: this.botName.trim(),
        icon: this.avatarUrl.length > 0 ? this.avatarUrl : undefined
      })
      NECommonUtils.showToast($r('app.string.bot_create_success'))
      // 创建后拉取列表，把最新 bot 对象完整带回，避免 BotInfoPage 再次查找
      const listResult = await UserAIBotRepo.getUserAIBotList({ limit: 100 })
      let newBot: V2NIMUserAIBot | undefined = undefined
      if (listResult && listResult.bots && listResult.bots.length > 0) {
        // 按 createTime 降序取最新的
        let latestBot = listResult.bots[0]
        for (const bot of listResult.bots) {
          if ((bot.createTime ?? 0) > (latestBot.createTime ?? 0)) {
            latestBot = bot
          }
        }
        newBot = latestBot
      }
      this.pathStack.pop(newBot ?? this.accid)
    } catch (err) {
      NECommonUtils.showToast($r('app.string.bot_create_fail'))
      console.error('createUserAIBot error: ' + JSON.stringify(err))
    } finally {
      this.isSubmitting = false
    }
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.create_bot'),
          showDivideLine: true,
          leftButtonAction: () => {
            this.pathStack.pop()
          },
          rightButtonTitle: $r('app.string.common_save'),
          rightButtonColor: this.canSubmit() ? '#337EFF' : '#CCCCCC',
          rightButtonAction: () => {
            this.doCreate()
          }
        })

        // 头像行
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
        .backgroundColor(Color.White)
        .onClick(() => {
          this.chooseAvatarDialog.open()
        })

        // 分割线
        Divider()
          .strokeWidth(0.5)
          .color('#F0F0F0')
          .margin({ left: 16 })
          .backgroundColor(Color.White)

        // 昵称行
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
        .backgroundColor(Color.White)
        .onClick(() => {
          this.pathStack.pushPath({
            name: 'EditBotNamePage',
            param: new EditBotNameParam(this.accid, this.botName, this.avatarUrl, true),
            onPop: (popInfo) => {
              const name = popInfo.result as string
              if (name && name.trim().length > 0) {
                this.botName = name.trim()
              }
            }
          })
        })

        // 剩余区域灰色背景
        Column()
          .width('100%')
          .layoutWeight(1)
          .backgroundColor('#EFF1F4')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      const param = this.pathStack.getParamByName('CreateBotPage')[0] as string
      if (param && param.length > 0) {
        this.bindQrcode = param
      }
    })
  }
}

@Builder
export function CreateBotPageBuilder() {
  CreateBotPage()
}