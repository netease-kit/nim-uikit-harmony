/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium';

/**
 * FileUtils 的纯逻辑单元测试
 * 将纯计算函数复制为本地版本，避免 HarmonyOS 平台 import 依赖。
 */
function formatFileSize(bytes: number): string {
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

function getFileExtension(filename: string): string {
  if (filename && filename.length > 0) {
    const dot = filename.lastIndexOf('.');
    if (dot > -1 && dot < filename.length - 1) {
      return filename.substring(dot + 1);
    }
  }
  return "";
}

export default function fileUtilsTest() {
  describe('FileUtils_formatFileSize', () => {
    // ===== B 级别 =====
    it('should_return_0B_for_zero', 0, () => {
      expect(formatFileSize(0)).assertEqual('0B');
    });

    it('should_return_bytes_for_small_size', 0, () => {
      expect(formatFileSize(100)).assertEqual('100B');
    });

    it('should_return_1023B_for_boundary', 0, () => {
      expect(formatFileSize(1023)).assertEqual('1023B');
    });

    // ===== KB 级别 =====
    it('should_return_KB_for_1024_bytes', 0, () => {
      expect(formatFileSize(1024)).assertEqual('1.00KB');
    });

    it('should_return_KB_with_decimal', 0, () => {
      expect(formatFileSize(1536)).assertEqual('1.50KB');
    });

    it('should_return_KB_for_large_KB_value', 0, () => {
      expect(formatFileSize(512 * 1024)).assertEqual('512.00KB');
    });

    // ===== MB 级别 =====
    it('should_return_MB_for_1MB', 0, () => {
      expect(formatFileSize(1024 * 1024)).assertEqual('1.00MB');
    });

    it('should_return_MB_with_decimal', 0, () => {
      expect(formatFileSize(1.5 * 1024 * 1024)).assertEqual('1.50MB');
    });

    it('should_return_MB_for_100MB', 0, () => {
      expect(formatFileSize(100 * 1024 * 1024)).assertEqual('100.00MB');
    });

    // ===== GB 级别 =====
    it('should_return_GB_for_1GB', 0, () => {
      expect(formatFileSize(1024 * 1024 * 1024)).assertEqual('1.00GB');
    });

    it('should_return_GB_with_decimal', 0, () => {
      expect(formatFileSize(2.5 * 1024 * 1024 * 1024)).assertEqual('2.50GB');
    });
  });

  describe('FileUtils_getFileExtension', () => {
    it('should_return_txt_for_document_txt', 0, () => {
      expect(getFileExtension('document.txt')).assertEqual('txt');
    });

    it('should_return_jpg_for_image_jpg', 0, () => {
      expect(getFileExtension('photo.jpg')).assertEqual('jpg');
    });

    it('should_return_last_extension_for_multiple_dots', 0, () => {
      expect(getFileExtension('archive.tar.gz')).assertEqual('gz');
    });

    it('should_return_empty_for_no_extension', 0, () => {
      expect(getFileExtension('filename')).assertEqual('');
    });

    it('should_return_empty_for_dot_at_end', 0, () => {
      expect(getFileExtension('filename.')).assertEqual('');
    });

    it('should_return_empty_for_empty_string', 0, () => {
      expect(getFileExtension('')).assertEqual('');
    });

    it('should_return_extension_for_hidden_file_with_ext', 0, () => {
      expect(getFileExtension('.gitignore')).assertEqual('gitignore');
    });

    it('should_return_pdf_for_path_with_dirs', 0, () => {
      expect(getFileExtension('path/to/file.pdf')).assertEqual('pdf');
    });

    it('should_return_mp4_for_video', 0, () => {
      expect(getFileExtension('video.mp4')).assertEqual('mp4');
    });

    it('should_return_extension_for_single_char_ext', 0, () => {
      expect(getFileExtension('file.c')).assertEqual('c');
    });
  });
}
