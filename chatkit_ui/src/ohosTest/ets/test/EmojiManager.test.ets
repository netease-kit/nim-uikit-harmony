/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it, beforeEach } from '@ohos/hypium';

/**
 * NEEmojiManager 的核心解析逻辑单元测试
 * 将 parseEmojiText 逻辑复制为本地模拟版本，避免 HarmonyOS 平台依赖。
 */

enum EmojiParseType {
  emoji = 1,
  text = 2,
}

class NEEmojiParseResult {
  type: EmojiParseType = EmojiParseType.text;
  startIndex: number = 0
  text?: string;
  emojiTag?: string;
}

class MockEmojiManager {
  private tagEmojiCache: Map<string, string> = new Map();
  private pattern = /\[([^\]]+)\]/g;

  addEmoji(tag: string, file: string) {
    this.tagEmojiCache.set(tag, file);
  }

  getEmojiByTag(tag: string): string | undefined {
    return this.tagEmojiCache.get(tag);
  }

  hasEmoji(inputString: string): boolean {
    let match = this.pattern.exec(inputString)
    // 重置 lastIndex
    this.pattern.lastIndex = 0;
    if (match !== null) {
      return true
    }
    return false
  }

  parseEmojiText(inputString: string): Array<NEEmojiParseResult> {
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
          emojiResult.emojiTag = tag;
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

export default function emojiManagerTest() {
  let manager: MockEmojiManager;

  describe('NEEmojiManager_parseEmojiText', () => {
    beforeEach(() => {
      manager = new MockEmojiManager();
      manager.addEmoji('[微笑]', 'emoji_smile.png');
      manager.addEmoji('[惊讶]', 'emoji_surprise.png');
      manager.addEmoji('[大笑]', 'emoji_laugh.png');
      manager.addEmoji('[哭泣]', 'emoji_cry.png');
    });

    it('should_parse_plain_text_only', 0, () => {
      let result = manager.parseEmojiText('hello world');
      expect(result.length).assertEqual(1);
      expect(result[0].type).assertEqual(EmojiParseType.text);
      expect(result[0].text).assertEqual('hello world');
    });

    it('should_parse_empty_string', 0, () => {
      let result = manager.parseEmojiText('');
      expect(result.length).assertEqual(1);
      expect(result[0].type).assertEqual(EmojiParseType.text);
      expect(result[0].text).assertEqual('');
    });

    it('should_parse_single_emoji', 0, () => {
      let result = manager.parseEmojiText('[微笑]');
      expect(result.length).assertEqual(1);
      expect(result[0].type).assertEqual(EmojiParseType.emoji);
      expect(result[0].emojiTag).assertEqual('[微笑]');
    });

    it('should_parse_emoji_with_text_before', 0, () => {
      let result = manager.parseEmojiText('你好[微笑]');
      expect(result.length).assertEqual(2);
      expect(result[0].type).assertEqual(EmojiParseType.text);
      expect(result[0].text).assertEqual('你好');
      expect(result[1].type).assertEqual(EmojiParseType.emoji);
      expect(result[1].emojiTag).assertEqual('[微笑]');
    });

    it('should_parse_emoji_with_text_after', 0, () => {
      let result = manager.parseEmojiText('[微笑]世界');
      expect(result.length).assertEqual(2);
      expect(result[0].type).assertEqual(EmojiParseType.emoji);
      expect(result[0].emojiTag).assertEqual('[微笑]');
      expect(result[1].type).assertEqual(EmojiParseType.text);
      expect(result[1].text).assertEqual('世界');
    });

    it('should_parse_emoji_between_text', 0, () => {
      let result = manager.parseEmojiText('你好[微笑]世界');
      expect(result.length).assertEqual(3);
      expect(result[0].type).assertEqual(EmojiParseType.text);
      expect(result[0].text).assertEqual('你好');
      expect(result[1].type).assertEqual(EmojiParseType.emoji);
      expect(result[2].type).assertEqual(EmojiParseType.text);
      expect(result[2].text).assertEqual('世界');
    });

    it('should_parse_multiple_emojis', 0, () => {
      let result = manager.parseEmojiText('[微笑][惊讶]');
      expect(result.length).assertEqual(2);
      expect(result[0].type).assertEqual(EmojiParseType.emoji);
      expect(result[0].emojiTag).assertEqual('[微笑]');
      expect(result[1].type).assertEqual(EmojiParseType.emoji);
      expect(result[1].emojiTag).assertEqual('[惊讶]');
    });

    it('should_parse_mixed_content_with_multiple_emojis', 0, () => {
      let result = manager.parseEmojiText('Hi[微笑]你好[大笑]世界');
      expect(result.length).assertEqual(5);
      expect(result[0].type).assertEqual(EmojiParseType.text);
      expect(result[0].text).assertEqual('Hi');
      expect(result[1].type).assertEqual(EmojiParseType.emoji);
      expect(result[1].emojiTag).assertEqual('[微笑]');
      expect(result[2].type).assertEqual(EmojiParseType.text);
      expect(result[2].text).assertEqual('你好');
      expect(result[3].type).assertEqual(EmojiParseType.emoji);
      expect(result[3].emojiTag).assertEqual('[大笑]');
      expect(result[4].type).assertEqual(EmojiParseType.text);
      expect(result[4].text).assertEqual('世界');
    });

    it('should_ignore_unknown_emoji_tags', 0, () => {
      // [未知] 不在缓存中，应当作为普通文本
      let result = manager.parseEmojiText('你好[未知]世界');
      // 由于 [未知] 不在 tagEmojiCache 中，正则匹配了但不进入 emoji 分支
      // 最终 lastMatchIndex 不变，后续文本作为一个整体
      expect(result.length).assertEqual(1);
      expect(result[0].type).assertEqual(EmojiParseType.text);
      expect(result[0].text).assertEqual('你好[未知]世界');
    });

    it('should_preserve_startIndex_for_emojis', 0, () => {
      let result = manager.parseEmojiText('AB[微笑]CD');
      // 'AB' at startIndex 0, [微笑] at startIndex 2, 'CD' at startIndex 6
      expect(result[0].startIndex).assertEqual(0);
      expect(result[1].startIndex).assertEqual(2);
      expect(result[2].startIndex).assertEqual(6);
    });

    it('should_handle_brackets_without_content', 0, () => {
      // [] 不匹配 pattern \[([^\]]+)\]
      let result = manager.parseEmojiText('hello[]world');
      expect(result.length).assertEqual(1);
      expect(result[0].type).assertEqual(EmojiParseType.text);
      expect(result[0].text).assertEqual('hello[]world');
    });
  });

  describe('NEEmojiManager_hasEmoji', () => {
    beforeEach(() => {
      manager = new MockEmojiManager();
    });

    it('should_return_true_when_bracket_text_exists', 0, () => {
      expect(manager.hasEmoji('hello [test] world')).assertTrue();
    });

    it('should_return_false_for_plain_text', 0, () => {
      expect(manager.hasEmoji('hello world')).assertFalse();
    });

    it('should_return_false_for_empty_brackets', 0, () => {
      expect(manager.hasEmoji('hello [] world')).assertFalse();
    });

    it('should_return_false_for_empty_string', 0, () => {
      expect(manager.hasEmoji('')).assertFalse();
    });

    it('should_return_true_for_emoji_tag', 0, () => {
      expect(manager.hasEmoji('[微笑]')).assertTrue();
    });
  });
}
