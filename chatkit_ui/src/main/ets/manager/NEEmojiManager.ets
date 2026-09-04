/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { Logger } from '@nimkit/common';
import common from '@ohos.app.ability.common';
import util from '@ohos.util';
import { NEStickerItem, NEStickerPackage } from '../model/NEStickerPackage';

const MEDIA_RESOURCE_TYPE: number = 20000

export enum NIMEmoticonType {
  file = 1,
  delete = 2,
}

export enum EmojiParseType {
  // 表情
  emoji = 1,
  // 文本
  text = 2,
}

export class NEEmojiParseResult {
  // 解析类型
  type: EmojiParseType = EmojiParseType.text;
  //开始坐标
  startIndex: number = 0
  // 解析文本内容
  text?: string;
  // 解析表情
  emoji?: NIMInputEmoticon;
}

export class NIMInputEmoticon {
  type: NIMEmoticonType = NIMEmoticonType.file;
  id?: string;
  tag?: string;
  file?: string;
}

export class EmojiDataModel {
  sourceData: Array<NIMInputEmoticon> = [];
}

@ObservedV2
export class NEEmojiManager {
  public static instance: NEEmojiManager = new NEEmojiManager()
  @Trace dataModel: EmojiDataModel = new EmojiDataModel();
  @Trace private registeredStickerPackages: NEStickerPackage[] = []
  @Trace private registeredStickerPackageRevision: number = 0
  public deleteEmoji: NIMInputEmoticon = new NIMInputEmoticon();
  // 根据文件名获取表情
  private fileEmojiCache: Map<string, NIMInputEmoticon> = new Map();
  // 根据tag获取表情
  private tagEmojiCache: Map<string, NIMInputEmoticon> = new Map();
  private pattern = /\[([^\]]+)\]/g;

  private constructor() {
  }

  public get stickerPackages(): NEStickerPackage[] {
    return this.registeredStickerPackages.slice()
  }

  public get stickerPackageRevision(): number {
    return this.registeredStickerPackageRevision
  }

  private isValidMediaResource(resource: Resource): boolean {
    return resource.id > 0 && resource.bundleName.length > 0 && resource.moduleName.length > 0
      && resource.type === MEDIA_RESOURCE_TYPE
  }

  private normalizeStickerPackage(stickerPackage: NEStickerPackage): NEStickerPackage | undefined {
    const packageId = stickerPackage.id.trim()
    if (packageId.length === 0 || stickerPackage.stickers.length === 0
      || !this.isValidMediaResource(stickerPackage.tabIcon)
      || !this.isValidMediaResource(stickerPackage.selectedTabIcon)) {
      return undefined
    }
    const stickers: NEStickerItem[] = []
    const positions: Map<string, number> = new Map<string, number>()
    for (const sticker of stickerPackage.stickers) {
      const stickerId = sticker.id.trim()
      const fileName = sticker.fileName.trim()
      if (stickerId.length === 0 || fileName.length === 0 || !this.isValidMediaResource(sticker.image)) {
        return undefined
      }
      const normalizedSticker = new NEStickerItem(stickerId, sticker.image, fileName)
      const position = positions.get(stickerId)
      if (position === undefined) {
        positions.set(stickerId, stickers.length)
        stickers.push(normalizedSticker)
      } else {
        stickers[position] = normalizedSticker
      }
    }
    return new NEStickerPackage(packageId, stickerPackage.tabIcon, stickerPackage.selectedTabIcon, stickers)
  }

  public setStickerPackages(packages: NEStickerPackage[]): void {
    const result: NEStickerPackage[] = []
    const positions: Map<string, number> = new Map<string, number>()
    for (const stickerPackage of packages) {
      const normalizedPackage = this.normalizeStickerPackage(stickerPackage)
      if (normalizedPackage === undefined) {
        continue
      }
      const position = positions.get(normalizedPackage.id)
      if (position === undefined) {
        positions.set(normalizedPackage.id, result.length)
        result.push(normalizedPackage)
      } else {
        result[position] = normalizedPackage
      }
    }
    this.registeredStickerPackages = result
    this.registeredStickerPackageRevision++
  }

  public addStickerPackage(stickerPackage: NEStickerPackage): boolean {
    const normalizedPackage = this.normalizeStickerPackage(stickerPackage)
    if (normalizedPackage === undefined) {
      return false
    }
    const packages = this.registeredStickerPackages.slice()
    const index = packages.findIndex((item: NEStickerPackage): boolean => item.id === normalizedPackage.id)
    if (index >= 0) {
      packages[index] = normalizedPackage
    } else {
      packages.push(normalizedPackage)
    }
    this.registeredStickerPackages = packages
    this.registeredStickerPackageRevision++
    return true
  }

  public clearStickerPackages(): void {
    this.registeredStickerPackages = []
    this.registeredStickerPackageRevision++
  }

  // 初始化表情管理器
  public setup(): void {
    // 获取表情列表
    if (this.dataModel.sourceData.length === 0) {
      this.getEmojiList();
    }
  }

  // 获取表情列表
  async getEmojiList() {
    this.deleteEmoji.file = 'emoji_del_normal.png';
    this.deleteEmoji.type = NIMEmoticonType.delete;
    let context = getContext() as common.UIAbilityContext;
    context.resourceManager.getRawFileContent('emoji_en.json', (err, rawFile) => {
      if (err) {
        Logger.error('ChatKitUI', 'net ease getRawFileContent failed, err is: ' + err)
        return
      }
      try {
        let textDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true })
        let retStr = textDecoder.decode(rawFile);
        let dataModel: EmojiDataModel = JSON.parse(retStr);
        this.dataModel = dataModel;
        dataModel.sourceData.forEach((emoji) => {
          emoji.type = NIMEmoticonType.file;
          if (emoji.file !== undefined) {
            this.fileEmojiCache.set(emoji.file, emoji);
          }
          if (emoji.tag !== undefined) {
            this.tagEmojiCache.set(emoji.tag, emoji);
          }
        })
      } catch (e) {
        Logger.error('ChatKitUI', 'net ease get emoji list failed, err is: ' + e)
      }
    })
    this.fileEmojiCache.set(this.deleteEmoji.file, this.deleteEmoji);
  }

  getEmojiByName(fileName: string): NIMInputEmoticon | undefined {
    return this.fileEmojiCache.get(fileName)
  }

  getEmojiByTag(tag: string): NIMInputEmoticon | undefined {
    return this.tagEmojiCache.get(tag)
  }

  public hasEmoji(inputString: string): boolean {
    let match = this.pattern.exec(inputString)
    if (match !== null) {
      return true
    }
    return false
  }

  public parseEmojiText(inputString: string): Array<NEEmojiParseResult> {
    // const inputString: string = "This is a [sample] input [string] with [multiple] occurrences of [brackets].";
    let array = new Array<NEEmojiParseResult>();
    let finish = false;
    let lastMatchIndex = 0;
    while (finish == false) {
      let match = this.pattern.exec(inputString)
      if (match !== null) {
        let tag = match[0];
        let emoji = this.getEmojiByTag(tag);
        if (emoji !== undefined) {
          const nonMatchString = inputString.substring(lastMatchIndex, match.index);
          if (nonMatchString.length > 0) {
            let textResult = new NEEmojiParseResult();
            textResult.type = EmojiParseType.text;
            textResult.text = nonMatchString;
            textResult.startIndex = lastMatchIndex
            array.push(textResult);
          }
          lastMatchIndex = match.index + match[0].length;
          let emojiResult = new NEEmojiParseResult();
          emojiResult.type = EmojiParseType.emoji;
          emojiResult.emoji = emoji;
          emojiResult.startIndex = match.index
          array.push(emojiResult);
        }
      } else {
        if (lastMatchIndex < inputString.length) {
          let textResult = new NEEmojiParseResult();
          textResult.type = EmojiParseType.text;
          textResult.text = inputString.substring(lastMatchIndex, inputString.length);
          textResult.startIndex = lastMatchIndex
          array.push(textResult);
        }
        finish = true;
      }
    }
    if (array.length == 0) {
      let textResult = new NEEmojiParseResult();
      textResult.type = EmojiParseType.text;
      textResult.text = inputString;
      array.push(textResult);
    }
    return array;
  }
}
