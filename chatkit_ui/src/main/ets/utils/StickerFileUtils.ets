/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

function trimUnderscores(value: string): string {
  let result = value
  while (result.startsWith('_')) {
    result = result.substring(1)
  }
  while (result.endsWith('_')) {
    result = result.substring(0, result.length - 1)
  }
  return result
}

export function buildStickerTempFileName(fileName: string, timestamp: number = Date.now()): string {
  const pathParts = fileName.replaceAll('\\', '/').split('/')
  const sourceName = pathParts.length > 0 ? pathParts[pathParts.length - 1] : ''
  const dotIndex = sourceName.lastIndexOf('.')
  const sourceBaseName = dotIndex > 0 ? sourceName.substring(0, dotIndex) : sourceName
  const sourceExtension = dotIndex > 0 ? sourceName.substring(dotIndex + 1).toLowerCase() : 'png'
  const normalizedBaseName = trimUnderscores(sourceBaseName.replace(/[^A-Za-z0-9_-]+/g, '_'))
  const normalizedExtension = sourceExtension.replace(/[^A-Za-z0-9]+/g, '') || 'png'
  const safeBaseName = normalizedBaseName.length > 0 ? normalizedBaseName : 'sticker'
  return `${timestamp}_${safeBaseName}.${normalizedExtension}`
}

export function toExactArrayBuffer(data: Uint8Array): ArrayBuffer {
  return data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength)
}

export function writeStickerBufferSync(fd: number, buffer: ArrayBuffer,
  writer: (fd: number, buffer: ArrayBuffer) => number): void {
  let writtenBytes = 0
  while (writtenBytes < buffer.byteLength) {
    const remaining = buffer.slice(writtenBytes)
    const currentWritten = writer(fd, remaining)
    if (currentWritten <= 0 || currentWritten > remaining.byteLength) {
      throw new Error('Sticker image write failed')
    }
    writtenBytes += currentWritten
  }
}
