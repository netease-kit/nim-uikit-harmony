/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { filePreview } from '@kit.PreviewKit';
import { BusinessError } from '@kit.BasicServicesKit';


export function openFileWithApp(fileUri: string, fileName: string, fileExt: string, context: Context) {
  let displayInfo: filePreview.DisplayInfo = {
    x: 100,
    y: 100,
  };
  let fileInfo: filePreview.PreviewInfo = {
    title: fileName,
    uri: fileUri,
    mimeType: getOpenFileType(fileExt)
  };
  filePreview.openPreview(context, fileInfo, displayInfo).then(() => {
    console.info('Succeeded in opening preview');
  }).catch((err: BusinessError) => {
    console.error(`Failed to open preview, err.code = ${err.code}, err.message = ${err.message}`);
  });
}

export function getOpenFileType(fileExt: string): string {

  if (fileExt.includes('txt')) {
    return 'text/plain'
  } else if (fileExt.includes('cpp')) {
    return 'text/x-c++src'
  } else if (fileExt.includes('c')) {
    return 'text/x-csrc'
  } else if (fileExt.includes('h')) {
    return 'text/x-chdr'
  } else if (fileExt.includes('java')) {
    return 'text/x-java'
  } else if (fileExt.includes('xhtml')) {
    return 'application/xhtml+xml'
  } else if (fileExt.includes('xml')) {
    return 'text/xml'
  } else if (fileExt.includes('html') || fileExt.includes('htm')) {
    return 'text/html'
  } else if (fileExt.includes('pdf')) {
    return 'application/pdf'
  } else if (fileExt.includes('jpg')) {
    return 'image/jpeg'
  } else if (fileExt.includes('png')) {
    return 'image/png'
  } else if (fileExt.includes('gif')) {
    return 'image/gif'
  } else if (fileExt.includes('webp')) {
    return 'image/webp'
  } else if (fileExt.includes('bmp')) {
    return 'image/bmp'
  } else if (fileExt.includes('svg')) {
    return 'image/svg+xml'
  } else if (fileExt.includes('m4a')) {
    return 'audio/mp4a-latm'
  } else if (fileExt.includes('mp3')) {
    return 'audio/mpeg'
  } else if (fileExt.includes('aac')) {
    return 'audio/aac'
  } else if (fileExt.includes('ogg')) {
    return 'audio/ogg'
  } else if (fileExt.includes('wav')) {
    return 'audio/x-wav'
  } else if (fileExt.includes('mp4')) {
    return 'video/mp4'
  } else if (fileExt.includes('mkv')) {
    return 'video/x-matroska'
  } else if (fileExt.includes('ts')) {
    return 'video/mp2ts'
  }

  return ' '
}
