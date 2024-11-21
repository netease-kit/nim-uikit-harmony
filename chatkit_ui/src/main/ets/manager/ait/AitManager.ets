/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { accountAll, AitMessage } from '@nimkit/chatkit';
import { AitModel } from '@nimkit/chatkit/src/main/ets/model/ait/AitModel';

export class AitManager {
  aitModel: AitModel = new AitModel()

  getAitModel(): AitModel | undefined {
    if (this.aitModel.aitBlocks.size > 0) {
      return this.aitModel
    }
    return undefined
  }

  // 通过@文本添加@用户
  addAitWithText(account: string, name: string, startIndex: number): void {
    this.aitModel.addAitMember(account, name, startIndex);
  }

  // 清理@用户，在发送之后调用
  cleanAit(): void {
    this.aitModel.reset();
  }

  // 复制@用户信息，用户撤回消息使用
  forkAit(aitContactsModel: AitModel): void {
    this.aitModel.fork(aitContactsModel);
  }

  // @用户 是否在文本最后，如果在文本最后，需要在文本后面添加空格
  aitEnd(text: string): boolean {
    const len = text.length;
    for (const element of this.aitModel.aitBlocks.values()) {
      for (const segment of element.segments) {
        if (segment.start < len && segment.end >= len) {
          return true;
        }
      }
    }
    return false;
  }

  /**
   * 根据插入后的Text 文案, segment 移位或者删除。
   * 返回被删除的AitMsg信息
   * @param deletedText 删除后的字符串
   * @param endIndex 删除的结束位置
   * @param length 删除的长度
   * @returns
   */
  deleteAitWithText(deletedText: string, endIndex: number, length: number): AitMessage | null {
    return this.aitModel.deleteAitUser(deletedText, endIndex, length);
  }

  /**
   * 删除文本
   * @param endIndex
   * @param length
   */
  deleteText(endIndex: number, length: number) {
    this.aitModel.deleteText(endIndex, length)
  }

  /**
   * 新增Text输入，但输入的不是@
   * 会进行移位或者删除，如果在@XXX 中插入文本 @XXX 会被删除
   * @param endIndex 输入的结束位置
   * @param length 输入的长度
   */
  addTextWithoutAit(endIndex: number, length: number): void {
    this.aitModel.insertText(endIndex, length);
  }

  // 获取需要推送的用户列表
  getPushList(): string[] | undefined {
    const pushList: string[] = [];
    for (const key of this.aitModel.aitBlocks.keys()) {
      if (key === accountAll) {
        // pushList.length = 0;
        // const teamMembers: string[] = TeamMemberCache.getInstance().getAllMemberAccounts()
        // pushList.push(...teamMembers);
        return pushList;
      } else {
        pushList.push(key);
      }
    }
    if (pushList.length > 0) {
      return pushList;
    }
    return undefined
  }

  // 是否已经在@列表中
  haveBeAit(account: string): boolean {
    return this.aitModel.aitBlocks.has(account)
  }

  // 是否有@成员
  haveAitMember(): boolean {
    return Object.keys(this.aitModel.aitBlocks).length > 0;
  }

  // 光标移动到@后自动到后面
  resetAitCursor(baseIndex: number): number {
    for (const aitMsg of this.aitModel.aitBlocks.values()) {
      for (const segment of aitMsg.segments) {
        if (segment.start < baseIndex && segment.end + 1 > baseIndex) {
          return segment.end + 1;
        }
      }
    }
    return baseIndex;
  }
}


