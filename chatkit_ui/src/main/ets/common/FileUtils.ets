/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { fileShare } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class FileUtils {
  static formatFileSize(bytes: number): string {
    if (bytes < 1024) {
      return bytes + "B";
    } else if (bytes < 1024 * 1024) {
      return (bytes / 1024).toFixed(2) + "KB";
    } else if (bytes < 1024 * 1024 * 1024) {
      return (bytes / (1024 * 1024)).toFixed(2) + "MB";
    } else {
      return (bytes / (1024 * 1024 * 1024)).toFixed(2) + "GB";
    }
  }

  static getFileExtension(filename: string): string {
    if (filename && filename.length > 0) {
      const dot = filename.lastIndexOf('.');
      if (dot > -1 && dot < filename.length - 1) {
        return filename.substring(dot + 1);
      }
    }
    return "";
  }

  static openFile(path: string) {
    try {
      let uri = path;
      let policyInfo: fileShare.PolicyInfo = {
        uri: uri,
        operationMode: fileShare.OperationMode.READ_MODE,
      };
      let policies: Array<fileShare.PolicyInfo> = [policyInfo];
      fileShare.activatePermission(policies).then(() => {
        console.info("activatePermission successfully");

      }).catch(async (err: BusinessError<Array<fileShare.PolicyErrorResult>>) => {
        console.error("activatePermission failed with error message: " + err.message + ", error code: " + err.code);
        if (err.code == 13900001 && err.data) {
          for (let i = 0; i < err.data.length; i++) {
            console.error("error code : " + JSON.stringify(err.data[i].code));
            console.error("error uri : " + JSON.stringify(err.data[i].uri));
            console.error("error reason : " + JSON.stringify(err.data[i].message));
            if (err.data[i].code == fileShare.PolicyErrorCode.PERMISSION_NOT_PERSISTED) {
              await fileShare.persistPermission(policies);
            }
          }
        }
      });
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      console.error('activatePermission failed with err: ' + JSON.stringify(err));
    }
  }
}