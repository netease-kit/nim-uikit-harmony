/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { media } from '@kit.MediaKit';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { AsyncCallback } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';

const TAG = 'net ease'

export class NEAudioMetaManager {
  public static instance: NEAudioMetaManager = new NEAudioMetaManager()

  // 获取音频专辑封面(Resource 文件夹下)
  async fetchMetadataFromFdSrcByCallback(fileName: string, callback: AsyncCallback<image.PixelMap>) {
    if (canIUse("SystemCapability.Multimedia.Media.AVMetadataExtractor")) {
      // 创建AVMetadataExtractor对象
      let avMetadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor()

      // 设置fdSrc
      avMetadataExtractor.fdSrc = await getContext(this).resourceManager.getRawFd(fileName);

      // 获取元数据（callback模式）
      avMetadataExtractor.fetchMetadata((error, metadata) => {
        if (error) {
          console.error(TAG, `fetchMetadata callback failed, err = ${JSON.stringify(error)}`)
          return
        }
        console.info(TAG, `fetchMetadata callback success, genre: ${metadata.genre}`)
      })

      //获取专辑封面（callback模式）
      avMetadataExtractor.fetchAlbumCover((err, pixelMap) => {
        if (err) {
          console.error(TAG, `fetchAlbumCover callback failed, err = ${JSON.stringify(err)}`)
          return
        }
        if (callback) {
          callback(err, pixelMap);
        }

        // 释放资源（callback模式）
        avMetadataExtractor.release((error) => {
          if (error) {
            console.error(TAG, `release failed, err = ${JSON.stringify(error)}`)
            return
          }
          console.info(TAG, `release success.`)
        })
      })
    }
  }

  // 使用fs文件系统打开沙箱地址获取媒体文件地址，设置dataSrc属性，获取音频元数据并打印
  async fetchMetadataFromDataSrc(filePath: string, callback: AsyncCallback<media.AVMetadata>) {

    let fd: number = fileIo.openSync(filePath, 0o0).fd;
    let fileSize: number = fileIo.statSync(filePath).size;
    // 设置dataSrc描述符，通过callback从文件中获取资源，写入buffer中
    let dataSrc: media.AVDataSrcDescriptor = {
      fileSize: fileSize,
      callback: (buffer, len, pos) => {
        if (buffer == undefined || len == undefined || pos == undefined) {
          console.error(TAG, `dataSrc callback param invalid`)
          return -1
        }

        class Option {
          offset: number | undefined = 0;
          length: number | undefined = len;
          position: number | undefined = pos;
        }

        let options = new Option();
        let num = fileIo.readSync(fd, buffer, options)
        console.info(TAG, 'readAt end, num: ' + num)
        if (num > 0 && fileSize >= pos) {
          return num;
        }
        return -1;
      }
    }

    if (canIUse("SystemCapability.Multimedia.Media.AVMetadataExtractor")) {
      // 创建AVMetadataExtractor对象
      let avMetadataExtractor = await media.createAVMetadataExtractor()
      // 设置dataSrc
      avMetadataExtractor.dataSrc = dataSrc;

      // 获取元数据（promise模式）
      let metadata = await avMetadataExtractor.fetchMetadata()
      console.info(TAG, `get meta data, mimeType: ${metadata.mimeType}`)

      // 获取专辑封面（promise模式）
      if (callback) {
        callback(undefined, metadata);
      }

      // 释放资源（promise模式）
      avMetadataExtractor.release()
      console.info(TAG, `release data source success.`)
    }
  }
}