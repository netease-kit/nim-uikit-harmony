/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { NECommonUtils } from '../utils/NECommonUtils';
import { PermissionsUtils } from '../utils/PermissionsUtils';

@CustomDialog
export struct ChooseAvatarDialog {
  controller?: CustomDialogController
  // 使用UIExtensionAbility：将common.UIAbilityContext 替换为common.UIExtensionContext
  context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  onImageChosen?: (url: string) => void

  // 显示相机选择器
  async showCameraPicker() {
    PermissionsUtils.reqPermissionsFromUser(['ohos.permission.CAMERA'], this.context).then(async (result) => {
      if (result.grantStatus == true) {
        try {
          // 相机选择器的配置信息
          let pickerProfile: cameraPicker.PickerProfile = {
            cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK
          };

          // 相机选择器的媒体类型
          let mediaTypes: cameraPicker.PickerMediaType[] = [
            cameraPicker.PickerMediaType.PHOTO,// 拍照模式
          // cameraPicker.PickerMediaType.VIDEO,// 录制模式
          ]

          let pickerResult: cameraPicker.PickerResult =
            await cameraPicker.pick(this.context, mediaTypes, pickerProfile);
          if (this.onImageChosen && pickerResult.resultCode == 0 && pickerResult.resultUri.length > 0) {
            this.onImageChosen(pickerResult.resultUri)
          }
          console.log("the pick pickerResult is:" + JSON.stringify(pickerResult));
        } catch (error) {
          let err = error as BusinessError;
          console.error(`the pick call failed. error code: ${err.code}`);
        }
      } else {
        NECommonUtils.showToast($r('app.string.chat_permission_deny_tips'))
      }
    })
  }

  // 显示相册选择器
  async showPhotoPicker() {
    console.log("net ease show photo picker");
    const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    // 过滤选择媒体文件类型为IMAGE
    photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    // 选择媒体文件的最大数目
    photoSelectOptions.maxSelectNumber = 1;

    const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
    photoViewPicker.select(photoSelectOptions)
      .then(async (photoSelectResult: photoAccessHelper.PhotoSelectResult) => {
        if (this.onImageChosen && photoSelectResult.photoUris.length > 0) {
          this.onImageChosen(photoSelectResult.photoUris[0])
        }
        console.info('net ease photoViewPicker.select to file succeed and uris are:' + photoSelectResult.photoUris);
      }).catch((err: BusinessError) => {
      console.error(`net ease Invoke photoViewPicker.select failed, code is ${err.code}, message is ${err.message}`);
    })
  }

  takePicture = () => {
    this.showCameraPicker()
    this.cancel()
  }
  goPhoto = () => {
    this.showPhotoPicker()
    this.cancel()
  }
  cancel = () => {
    this.controller?.close()
  }

  build() {
    Column() {
      Column() {
        Text($r("app.string.dialog_take_picture"))
          .fontSize(14)
          .fontColor("#333333")
          .textAlign(TextAlign.Center)
          .height(42)
          .width('100%')
          .onClick(this.takePicture)

        Row()
          .height(1)
          .width('100%')
          .backgroundColor("#EFF1F4")

        Text($r("app.string.dialog_photo"))
          .fontSize(14)
          .fontColor("#333333")
          .textAlign(TextAlign.Center)
          .height(42)
          .width('100%')
          .onClick(this.goPhoto)
      }
      .height(85)
      .width('100%')
      .backgroundColor(Color.White)
      .borderRadius(12)
      .margin({ left: 12, right: 12 })

      Column() {
        Text($r('app.string.mine_edit_cancel'))
          .fontSize(14)
          .fontColor("#333333")
          .textAlign(TextAlign.Center)
          .height(42)
          .width('100%')
          .onClick(this.cancel)
      }
      .height(42)
      .width('100%')
      .backgroundColor(Color.White)
      .borderRadius(12)
      .margin({ top: 10, left: 12, right: 12 })

    }
    .backgroundColor(Color.Transparent)
  }
}
