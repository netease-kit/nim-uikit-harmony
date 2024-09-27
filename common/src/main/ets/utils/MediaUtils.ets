/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import picker from '@ohos.file.picker';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { dataSharePredicates } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { camera, cameraPicker } from '@kit.CameraKit';

export class SelectResult {
  public uris: Array<string> = [];
  public errorMsg?: string;
  // 视频宽度(只支持视频)
  public width?: number;
  // 视频高度(只支持视频)
  public height?: number;
  // 文件大小

  // 文件类型
  public type = cameraPicker.PickerMediaType.PHOTO;
}

export class MediaUtils {
  // 显示相册选择器(包含视频照片)
  static async showMediaPicker(): Promise<SelectResult> {
    console.log("net ease show photo picker");
    const result: SelectResult = await new Promise((resolve: Function) => {
      const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      // 过滤选择媒体文件类型为IMAGE
      photoSelectOptions.MIMEType =
        photoAccessHelper.PhotoViewMIMETypes.IMAGE_VIDEO_TYPE;
      // 选择媒体文件的最大数目
      photoSelectOptions.maxSelectNumber = 1;
      const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
      photoViewPicker.select(photoSelectOptions)
        .then(async (photoSelectResult: photoAccessHelper.PhotoSelectResult) => {
          console.info('net ease photoViewPicker.select to file succeed and uris are:' + photoSelectResult.photoUris);
          const selectResult = new SelectResult();
          console.info('net ease uris length is: ' + photoSelectResult.photoUris.length)
          if (photoSelectResult.photoUris.length > 0) {
            let predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
            let uri = photoSelectResult.photoUris[0];
            predicates.equalTo(photoAccessHelper.PhotoKeys.URI, uri.toString());
            let fetchOptions: photoAccessHelper.FetchOptions = {
              fetchColumns: [photoAccessHelper.PhotoKeys.WIDTH, photoAccessHelper.PhotoKeys.HEIGHT],
              predicates: predicates
            };
            console.info('net ease first uri is:' + uri);
            let context = getContext(photoSelectOptions) as common.UIAbilityContext;
            let fetchResult = await photoAccessHelper.getPhotoAccessHelper(context).getAssets(fetchOptions)
            let photoAsset = await fetchResult.getFirstObject()
            if (photoAsset.photoType === photoAccessHelper.PhotoType.VIDEO) {
              let srcWidth = photoAsset.get(photoAccessHelper.PhotoKeys.WIDTH) as number;
              let srcHeight = photoAsset.get(photoAccessHelper.PhotoKeys.HEIGHT) as number;
              selectResult.width = srcWidth;
              selectResult.height = srcHeight;
              console.log(`net ease select video width ${srcWidth} video height ${srcHeight}`);
              selectResult.type = cameraPicker.PickerMediaType.VIDEO;
            } else {
              selectResult.type = cameraPicker.PickerMediaType.PHOTO;
            }
            selectResult.uris.push(uri);
          }
          resolve(selectResult);
        })
        .catch((err: BusinessError) => {
          console.error(`net ease Invoke photoViewPicker.select failed, code is ${err.code}, message is ${err.message}`);
          const selectResult = new SelectResult();
          selectResult.errorMsg =
            `net ease Invoke photoViewPicker.select failed, code is ${err.code}, message is ${err.message}`;
          resolve(selectResult);
        })
    });
    return result;
  }

  // 显示相册选择器
  static async showPhotoPicker(): Promise<SelectResult> {
    console.log("net ease show photo picker");
    const result: SelectResult = await new Promise((resolve: Function) => {
      const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      // 过滤选择媒体文件类型为IMAGE
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      // 选择媒体文件的最大数目
      photoSelectOptions.maxSelectNumber = 1;
      const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
      photoViewPicker.select(photoSelectOptions)
        .then(async (photoSelectResult: photoAccessHelper.PhotoSelectResult) => {
          console.info('net ease photoViewPicker.select to file succeed and uris are:' + photoSelectResult.photoUris);
          const selectResult = new SelectResult();
          console.info('net ease uris length is: ' + photoSelectResult.photoUris.length)
          if (photoSelectResult.photoUris.length > 0) {
            console.info('net ease first uri is:' + photoSelectResult.photoUris[0]);
            selectResult.uris.push(photoSelectResult.photoUris[0]);
          }
          resolve(selectResult);
        })
        .catch((err: BusinessError) => {
          console.error(`net ease Invoke photoViewPicker.select failed, code is ${err.code}, message is ${err.message}`);
          const selectResult = new SelectResult();
          selectResult.errorMsg =
            `net ease Invoke photoViewPicker.select failed, code is ${err.code}, message is ${err.message}`;
          resolve(selectResult);
        })
    });
    return result;
  }

  // 显示相册选择器
  static async showVideoPicker(): Promise<SelectResult> {
    console.log("net ease show photo picker");
    const result: SelectResult = await new Promise((resolve: Function) => {
      const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      // 过滤选择媒体文件类型为IMAGE
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE;
      // 选择媒体文件的最大数目
      photoSelectOptions.maxSelectNumber = 1;
      let uris: Array<string> = [];
      const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
      photoViewPicker.select(photoSelectOptions)
        .then(async (photoSelectResult: photoAccessHelper.PhotoSelectResult) => {

          uris = photoSelectResult.photoUris;
          console.info('net ease photoViewPicker.select to file succeed and uris are:' + uris);
          const selectResult = new SelectResult();
          console.info('net ease uris length is: ' + photoSelectResult.photoUris.length)
          if (photoSelectResult.photoUris.length > 0) {
            let predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
            let uri = photoSelectResult.photoUris[0];
            predicates.equalTo(photoAccessHelper.PhotoKeys.URI, uri.toString());
            let fetchOptions: photoAccessHelper.FetchOptions = {
              fetchColumns: [photoAccessHelper.PhotoKeys.WIDTH, photoAccessHelper.PhotoKeys.HEIGHT],
              predicates: predicates
            };
            console.info('net ease first uri is:' + uri);
            let context = getContext(photoSelectOptions) as common.UIAbilityContext;
            let fetchResult = await photoAccessHelper.getPhotoAccessHelper(context).getAssets(fetchOptions)
            let photoAsset = await fetchResult.getFirstObject()
            let srcWidth = photoAsset.get(photoAccessHelper.PhotoKeys.WIDTH) as number;
            let srcHeight = photoAsset.get(photoAccessHelper.PhotoKeys.HEIGHT) as number;
            selectResult.width = srcWidth;
            selectResult.height = srcHeight;
            console.log(`net ease select video width ${srcWidth} video height ${srcHeight}`);
            selectResult.uris.push(uri);
          }
          resolve(selectResult);
        })
        .catch((err: BusinessError) => {
          console.error(`net ease Invoke photoViewPicker.select failed, code is ${err.code}, message is ${err.message}`);
          const selectResult = new SelectResult();
          selectResult.errorMsg =
            `net ease Invoke photoViewPicker.select failed, code is ${err.code}, message is ${err.message}`;
          resolve(selectResult);
        })
    });
    return result;
  }

  // 文件选择器
  static async showFilePicker(): Promise<SelectResult> {
    console.log("net ease show file picker");
    const result: SelectResult = await new Promise((resolve: Function) => {
      let uris: Array<string> = [];
      let documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;

      const documentViewPicker = new picker.DocumentViewPicker(); // 创建文件选择器实例
      documentViewPicker.select(documentSelectOptions).then((documentSelectResult: Array<string>) => {
        uris = documentSelectResult;
        console.info('net ease documentViewPicker.select to file succeed and uris are:' + uris);
        const selectResult = new SelectResult();
        if (uris.length > 0) {
          console.log("net ease first uri is:" + uris[0]);
          selectResult.uris.push(uris[0]);
        }
        resolve(selectResult);
      }).catch((err: BusinessError) => {
        console.error(`net ease Invoke documentViewPicker.select failed, code is ${err.code}, message is ${err.message}`);
        const selectResult = new SelectResult();
        selectResult.errorMsg =
          `net ease Invoke documentViewPicker.select failed, code is ${err.code}, message is ${err.message}`;
        resolve(selectResult);
      })
    });
    return result;
  }

  // 显示相机选择器
  static async showCameraPicker(context: common.UIAbilityContext,
    mediaType: cameraPicker.PickerMediaType): Promise<SelectResult> {

    const result: SelectResult = await new Promise((resolve: Function) => {
      try {
        // 相机选择器的配置信息
        let pickerProfile: cameraPicker.PickerProfile = {
          cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK
        };

        // 相机选择器的媒体类型
        let mediaTypes: cameraPicker.PickerMediaType[] = [
          mediaType
        ]

        let selectResult = new SelectResult();
        let context1 = getContext(selectResult) as common.UIAbilityContext;

        cameraPicker.pick(context1, mediaTypes, pickerProfile).then((result) => {
          let uri = result.resultUri
          selectResult.uris.push(uri);
          selectResult.type = result.mediaType;
          console.log("net ease the pick pickerResult is:" + JSON.stringify(result));
          resolve(selectResult);
        });

      } catch (error) {
        let err = error as BusinessError;
        let selectResult = new SelectResult();
        selectResult.errorMsg = err.code + ":" + err.message;
        selectResult.errorMsg =
          `net ease Invoke camera  failed, code is ${err.code}, message is ${err.message}`;
        resolve(selectResult);
      }
    });
    return result;

  }
}