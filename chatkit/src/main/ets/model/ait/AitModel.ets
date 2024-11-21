/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { AitMessage } from './AitMessage'
import { plainToClass, Transform, Type } from 'class-transformer'
import 'reflect-metadata'
import { AitSegment } from './AitSegment'

//@所有人的Account
export const accountAll: string = "ait_all"

//@key
export const aitKey: string = 'yxAitMsg'

/**
 * 云信@功能集合
 */
export interface YxAitMsg {
  yxAitMsg?: Map<string, AitMessage>
}

export class AitModel {
  /**
   * key 为AccountID
   */
  @Type(() => Map)
  @Transform((param) => {
    const map = new Map<string, AitMessage>();
    if (param.value instanceof Map) {
      let params = param.value as Map<string, AitMessage>
      params.forEach((
        value, key
      ) => {
        map.set(key, value)
      })
    }
    return map;
  })
  aitBlocks: Map<string, AitMessage> = new Map()

  reset() {
    this.aitBlocks.clear()
  }

  /**
   * 删除一个@的用户
   * @param deletedText 文本
   * @param endIndex 删除的文本的光标所在位置
   * @param length 删除的文本的长度
   * @returns
   */
  deleteAitUser(deletedText: string, endIndex: number, length: number): AitMessage | null {
    //如果deletedText为空，直接返回
    if (deletedText.length <= 0) {
      return null
    }
    let len: number = deletedText.length;
    //如果aitBlocks 中有Value值和deletedText不匹配则返回
    let removedBlack: AitMessage | null = null;

    for (let aitMsg of this.aitBlocks.values()) {
      for (let segment of aitMsg.segments) {
        if (endIndex < segment.start) {
          segment.start -= length;
          segment.end -= length;
          continue;
        }
        if (len < segment.end + 1 ||
          deletedText.substring(segment.start, segment.end + 1) !== aitMsg.text) {
          removedBlack = new AitMessage(aitMsg.text, "");
          removedBlack.addSegment(segment.start, segment.end);
        }
      }
    }

    if (removedBlack !== null) {
      this.removeSegment(removedBlack, length);
    }

    return removedBlack;
  }

  /**
   * 删除文本
   * @param endIndex 删除后光标的位置
   * @param length 删除的长度
   */
  deleteText(endIndex: number, length: number) {
    let removedBlack: AitMessage | null = null;
    for (let aitMsg of this.aitBlocks.values()) {
      let deletedSegment: AitSegment | null = null
      for (let segment of aitMsg.segments) {
        if (endIndex < segment.start) {
          segment.start -= length;
          segment.end -= length;
          continue;
        } else if (endIndex < segment.end) {
          deletedSegment = segment
        }
      }
      if (deletedSegment !== null) {
        aitMsg.removeSegment(deletedSegment.start, deletedSegment.end)
      }
      if (aitMsg.segments.length <= 0) {
        removedBlack = aitMsg
      }
    }
    if (removedBlack !== null) {
      this.removeSegment(removedBlack, length)
    }
  }

  /**
   * 删除aitMsg中的segment,如果aitMsg中的segment为空，则删除aitMsg
   * 同时处理其他aitMsg中的segment的位置
   * @param removedBlack
   * @param deletedLen 删除的文本的长度，如果为正数则其他后面的前移，如果为负数，则其他不变
   */
  removeSegment(removedBlack: AitMessage, deletedLen: number): void {
    // 删除aitMsg中的segment,如果aitMsg中的segment为空，则删除aitMsg
    let aitMsg: AitMessage | undefined = undefined
    let removeKey: string = ''
    this.aitBlocks.forEach((value, key) => {
      if (value.text === removedBlack.text) {
        aitMsg = value
        removeKey = key
      }
    })
    if (aitMsg) {
      //artTs 语法要求,重新拷贝
      const aitMessage: AitMessage = aitMsg
      const start: number = removedBlack.segments[0].start;
      const end: number = removedBlack.segments[0].end;
      // 该段文字的长度，加上删除的长度,因为其在前面已经移了deletedLen位
      const length = end - start + 1 - deletedLen;
      aitMessage.removeSegment(start, end);
      if (aitMessage.segments.length === 0) {
        this.aitBlocks.delete(removeKey);
      }
      if (deletedLen > 0) {
        for (const aitMsg of this.aitBlocks.values()) {
          for (const segment of aitMsg.segments) {
            if (end <= segment.start) {
              segment.start -= length;
              segment.end -= length;
              continue;
            }
          }
        }
      }
    }
  }

  /**
   * 用户是否被@
   * @param accId
   * @returns
   */
  isUserBeenAit(accId: string | null): boolean {
    if (accId === null) {
      return false;
    }
    for (let key of this.aitBlocks.keys()) {
      if (key === accountAll) {
        return true;
      }
      if (key === accId) {
        return true;
      }
    }
    return false;
  }

  /**
   * 拷贝
   * @param aitModel
   */
  fork(aitModel: AitModel) {
    this.aitBlocks.clear()
    this.aitBlocks = aitModel.aitBlocks
  }

  /**
   * 根据插入后的Text 文案, segment 移位或者删除。
   * @param changedText
   * @param endIndex
   * @param length
   */
  insertText(endIndex: number, length: number): void {
    let removedBlack: AitMessage | null = null;
    const start: number = endIndex - length;
    for (let aitMsg of this.aitBlocks.values()) {
      for (let segment of aitMsg.segments) {
        if (start <= segment.start) {
          segment.start += length;
          segment.end += length;
          continue;
        }
        if (endIndex > segment.start && endIndex <= segment.end) {
          removedBlack = new AitMessage(aitMsg.text, "");
          removedBlack.addSegment(segment.start, segment.end);
          continue;
        }
      }
    }
    if (removedBlack !== null) {
      this.removeSegment(removedBlack, -1);
    }
  }

  /**
   * 添加@成员
   * @param account
   * @param name
   * @param start
   */
  addAitMember(account: string, name: string, start: number): void {
    for (let aitMsg of this.aitBlocks.values()) {
      for (let segment of aitMsg.segments) {
        if (start <= segment.start) {
          segment.start += name.length;
          segment.end += name.length;
          continue;
        }
      }
    }
    let aitBlock: AitMessage | undefined = this.aitBlocks.get(account);
    if (aitBlock === undefined) {
      aitBlock = new AitMessage(name, account);
      this.aitBlocks.set(account, aitBlock);
    }
    const end: number = start + name.length - 1;
    aitBlock.addSegment(start, end);
  }
}

/**
 * Extension 解析获得AitModel
 * @param extension
 * @returns
 */
export function getAitModelFromJson(extension?: string): AitModel | undefined {
  if (extension) {
    let obj: Record<string, Object> = JSON.parse(extension)
    for (let key of Object.entries(obj)) {
      if (key[0] === aitKey) {
        let trans: AitModelTrans = {
          aitBlocks: key[1]
        }
        let aitModel: AitModel = plainToClass(AitModel, trans, { enableImplicitConversion: true })
        if (aitModel.aitBlocks.size > 0) {
          return aitModel
        }

      }
    }
  }
  return undefined
}

interface AitModelTrans {
  aitBlocks: object
}