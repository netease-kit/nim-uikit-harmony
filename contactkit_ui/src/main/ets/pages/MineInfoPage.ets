/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMUser } from '@nimsdk/base';
import { pasteboard } from '@kit.BasicServicesKit';
import {
  AvatarColorUntil,
  AvatarItem,
  ChooseAvatarDialog,
  CommonAvatar,
  NavigationBackBuilder,
  NECommonUtils
} from '@nimkit/common';
import { ErrorUtils, NEFriendUserCache, StorageRepo } from '@nimkit/chatkit';
import { EditType, MineInfoItem } from '../model/MineInfoItem';
import { EditInfoViewModel } from '../model/EditInfoViewModel';
import { EditInfoParam } from './EditInfoPage';
import fs from '@ohos.file.fs';

@CustomDialog
export struct DatePickerDialog {
  controller?: CustomDialogController
  dateString?: string
  onDateChanged?: (value?: Date) => void
  selectedData?: Date
  viewModel = new EditInfoViewModel()

  build() {
    Column() {
      Row() {
        Button($r('app.string.mine_edit_cancel'), { type: ButtonType.Normal })
          .fontSize(13)
          .fontColor("#337EFF")
          .backgroundColor(Color.White)
          .width(60)
          .height(20)
          .margin({ left: 20 })
          .onClick(() => {
            this.controller?.close()
          })

        Row()
          .height(1)
          .layoutWeight(1)

        Button($r('app.string.mine_edit_sure'), { type: ButtonType.Normal })
          .fontSize(13)
          .fontColor("#337EFF")
          .backgroundColor(Color.White)
          .width(60)
          .height(20)
          .margin({ right: 20 })
          .onClick(() => {
            if (this.onDateChanged) {
              this.onDateChanged(this.selectedData)
            }
            this.controller?.close()
          })
      }
      .height(38)

      Row()
        .height(1)
        .width('100%')
        .backgroundColor("#EFF1F4")

      DatePicker({
        start: new Date('1970-1-1'),
        end: new Date(),
        selected: new Date(this.dateString)
      })
        .width('100%')
        .margin({ top: 9 })
        .backgroundColor(Color.White)
        .onDateChange((value) => {
          this.selectedData = value
        })
    }
    .backgroundColor(Color.White)
  }
}

// 跳转页面入口函数
@Builder
function MineInfoPageBuilder() {
  MineInfoPage()
}

@Component
export struct MineInfoPage {
  pathStack: NavPathStack = new NavPathStack()
  viewModel: EditInfoViewModel = new EditInfoViewModel()
  @State myUser?: V2NIMUser = NEFriendUserCache.mineUserCache?.user;
  @State nick?: string = this.myUser?.name;
  @State gender?: number = this.myUser?.gender;
  @State birthday?: string = this.myUser?.birthday;
  @State mobile?: string = this.myUser?.mobile;
  @State email?: string = this.myUser?.email;
  @State sign?: string = this.myUser?.sign;
  @State mineInfoItems1: MineInfoItem[] = [
    new MineInfoItem($r('app.string.mine_info_avatar'), this.myUser?.avatar, undefined, EditType.avatar),
    new MineInfoItem($r("app.string.person_info_nick"), undefined, this.myUser?.name, EditType.nick, 'EditInfoPage'),
    new MineInfoItem($r("app.string.mine_account_id"), undefined, this.myUser?.accountId, EditType.accountId, undefined,
      $r('app.media.copy_icon')),
    new MineInfoItem($r("app.string.person_info_gender"), undefined, this.getGenderString(), EditType.gender,
      "EditGenderPage"),
    new MineInfoItem($r("app.string.person_info_birthday"), undefined, this.myUser?.birthday, EditType.birthday),
    new MineInfoItem($r("app.string.person_info_mobile"), undefined, this.myUser?.mobile, EditType.mobile,
      'EditInfoPage'),
    new MineInfoItem($r("app.string.person_info_email"), undefined, this.myUser?.email, EditType.email, 'EditInfoPage'),

  ]
  @State mineInfoItems2: MineInfoItem[] = [
    new MineInfoItem($r("app.string.person_info_sign"), undefined, this.myUser?.sign, EditType.sign, 'EditInfoPage'),
  ]
  onDateChanged = (value?: Date) => {
    if (value && ErrorUtils.checkNetworkAndToast()) {
      const year = value?.getFullYear()
      const month = (value?.getMonth() ?? 0) + 1
      const day = value?.getDate()
      const formattedDate = `${year}-${month}-${day}`
      this.mineInfoItems1[4].subTitle = formattedDate
      this.viewModel.saveBirthday(formattedDate)
    }
  }
  onImageChosen = async (filePath: string) => {
    if (ErrorUtils.checkNetworkAndToast()) {
      try {
        const cacheDir = getContext(this).getApplicationContext().cacheDir
        const filePathSplit = filePath.split('/')
        const dir = cacheDir + '/' + filePathSplit[filePathSplit.length - 1]
        // 将文件 拷贝到 临时目录
        const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY)
        fs.copyFileSync(file.fd, dir)

        const task = StorageRepo.createUploadFileTask({
          filePath: dir,
          sceneName: 'nim_default_profile_icon'
        })
        if (task) {
          const url = await StorageRepo.uploadFile(task, (progress: number) => {
            // NECommonUtils.showToast($r('app.string.avatar_uploading', progress * 100))
          })
          await this.viewModel.saveAvatar(url)
          this.mineInfoItems1[0].subIcon = filePath
        }
      } catch (err) {
        console.error(err)
      }
    }
  }
  dateDialog: CustomDialogController = new CustomDialogController({
    builder: DatePickerDialog({ dateString: this.myUser?.birthday, onDateChanged: this.onDateChanged }),
    cornerRadius: 0,
    alignment: DialogAlignment.Bottom,
    backgroundColor: Color.White,
    height: 248,
    width: '100%'
  })
  chooseAvatarDialog: CustomDialogController = new CustomDialogController({
    builder: ChooseAvatarDialog({ onImageChosen: this.onImageChosen }),
    cornerRadius: 0,
    alignment: DialogAlignment.Bottom,
    backgroundColor: Color.Transparent,
    backgroundBlurStyle: BlurStyle.NONE,
    height: 140,
  })

  getGenderString() {
    return this.gender === 2 ? $r("app.string.person_gender_female") :
      (this.gender === 1 ? $r("app.string.person_gender_male") : $r("app.string.person_gender_unknown"))
  }

  // 拷贝内容到剪切板
  setPasteboard(content?: ResourceStr) {
    const pasteboardData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, content?.toString())
    const systemPasteboard = pasteboard.getSystemPasteboard()
    systemPasteboard.setData(pasteboardData).then(() => {
      NECommonUtils.showToast($r('app.string.copy_success'))
    })
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.mine_info'),
          backgroundColor: '#EFF1F4',
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        List() {
          ForEach(this.mineInfoItems1, (item: MineInfoItem) => {
            ListItem() {
              Column() {
                Row() {
                  Text(item.title)
                    .height(18)
                    .margin({ left: 16 })
                    .layoutWeight(1)

                  if (item.subIcon) {
                    CommonAvatar({
                      item: new AvatarItem(item.subIcon,
                        this.myUser?.name,
                        AvatarColorUntil.getBackgroundColorById(this.myUser?.accountId ?? ""))
                    })
                      .width(36)
                      .height(36)
                      .borderRadius(18)
                      .margin({ right: item.subIcon ? 17.54 : 9.54 })
                  }

                  if (item.subTitle) {
                    Text(item.subTitle)
                      .fontSize(14)
                      .fontColor('#A6ADB6')
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .margin({ right: item.subIcon ? 17.54 : 9.54 })
                      .textAlign(TextAlign.End)
                      .layoutWeight(2)
                      .height(38)
                  }

                  Image(item.rightIcon)
                    .width(item.editType === EditType.accountId ? 16 : 4.92)
                    .height(item.editType === EditType.accountId ? 16 : 9.54)
                    .margin({ right: item.editType === EditType.accountId ? 16 : 21.54 })
                    .objectFit(item.editType === EditType.accountId ? ImageFit.ScaleDown : ImageFit.Contain)
                    .onClick(() => {
                      if (item.editType === EditType.accountId) {
                        this.setPasteboard(item.subTitle)
                      }
                    })
                }
                .height((item.subIcon ? 64 : 46) - 1)
                .alignSelf(ItemAlign.Center)

                Row()
                  .height(1)
                  .width('100%')
                  .backgroundColor('#F5F8FC')
                  .margin({ left: 32 })
              }
              .height(item.subIcon ? 64 : 46)
              .onClick(() => {
                if (item.routerUrl) {
                  this.pathStack.pushPath({
                    name: item.routerUrl,
                    param: new EditInfoParam(item.title, item.subTitle, item.editType),
                    onPop: (popInfo: PopInfo) => {
                      if (item.editType == EditType.gender) {
                        this.gender = popInfo.result as number
                        item.subTitle = this.getGenderString()
                      } else {
                        item.subTitle = popInfo.result as string
                      }
                    }
                  })
                }

                if (item.editType == EditType.avatar) {
                  this.chooseAvatarDialog.open()
                }

                if (item.editType == EditType.birthday) {
                  this.dateDialog.open()
                }

              })
            }
            .height(item.subIcon ? 64 : 46)
          })
        }
        .borderRadius(8)
        .backgroundColor(Color.White)
        .margin({
          left: 20,
          right: 20,
          bottom: 12
        })

        List() {
          ForEach(this.mineInfoItems2, (item: MineInfoItem) => {
            ListItem() {
              Column() {
                Row() {
                  Text(item.title)
                    .height(18)
                    .margin({ left: 16 })
                    .layoutWeight(1)

                  if (item.subTitle) {
                    Text(item.subTitle)
                      .fontSize(14)
                      .fontColor('#A6ADB6')
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .margin({ right: 9.54 })
                      .textAlign(TextAlign.End)
                      .layoutWeight(2)
                      .height(38)
                  }

                  Image(item.rightIcon)
                    .width(4.92)
                    .height(9.54)
                    .margin({ right: 21.54 })
                }
                .height(45)
                .alignSelf(ItemAlign.Center)

                Row()
                  .height(1)
                  .width('100%')
                  .backgroundColor('#F5F8FC')
                  .margin({ left: 32 })
              }
              .height(46)
              .onClick(() => {
                if (item.routerUrl) {
                  this.pathStack.pushPath({
                    name: item.routerUrl,
                    param: new EditInfoParam(item.title, item.subTitle, item.editType),
                    onPop: (popInfo: PopInfo) => {
                      item.subTitle = popInfo.result as string
                    }
                  })
                }
              })
            }
            .height(46)
          })
        }
        .borderRadius(8)
        .backgroundColor(Color.White)
        .margin({
          left: 20,
          right: 20,
          bottom: 56 + 12
        })
      }
    }
    .hideTitleBar(true)
    .backgroundColor('#EFF1F4')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
  }
}