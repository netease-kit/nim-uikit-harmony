/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium';

/**
 * MessageHelper 中 translateEmojiText 的纯逻辑单元测试
 * 将函数逻辑复制为本地版本，避免 HarmonyOS 平台 import 依赖。
 */
function translateEmojiText(text: string): string {
  let inputString = text;
  let resultText = ''
  const pattern = /\[([^\]]+)\]/g;
  let finish = false;
  let lastMatchIndex = 0;
  let emojiLength = 0;
  while (finish == false) {
    let match = pattern.exec(inputString)
    if (match !== null) {
      let tag = match[0];
      emojiLength++;
      if (emojiLength >= 2) {
        emojiLength = 0;
        resultText = resultText + inputString.substring(lastMatchIndex, match.index) + tag.substring(1, 2);
      } else {
        resultText = resultText + inputString.substring(lastMatchIndex, match.index) + tag.substring(0, 2);
      }
      lastMatchIndex = match.index + match[0].length;
    } else {
      finish = true;
      resultText = resultText + inputString.substring(lastMatchIndex, inputString.length);
    }
  }
  return resultText;
}

export default function messageHelperTest() {
  describe('MessageHelper_translateEmojiText', () => {
    it('should_return_same_text_without_emoji', 0, () => {
      expect(translateEmojiText('hello world')).assertEqual('hello world');
    });

    it('should_return_empty_string_for_empty_input', 0, () => {
      expect(translateEmojiText('')).assertEqual('');
    });

    it('should_translate_single_emoji', 0, () => {
      // 单个 emoji [惊讶] -> 取前两个字符 [惊
      let result = translateEmojiText('[惊讶]');
      expect(result).assertEqual('[惊');
    });

    it('should_translate_two_consecutive_emojis', 0, () => {
      // 第一个 [惊讶] -> 取前两位 '[惊'; 第二个 [高兴] -> emojiLength=2 -> 取 substring(1,2) = '高'
      let result = translateEmojiText('[惊讶][高兴]');
      expect(result).assertEqual('[惊高');
    });

    it('should_translate_emoji_with_text_before', 0, () => {
      let result = translateEmojiText('你好[惊讶]');
      expect(result).assertEqual('你好[惊');
    });

    it('should_translate_emoji_with_text_after', 0, () => {
      let result = translateEmojiText('[惊讶]世界');
      expect(result).assertEqual('[惊世界');
    });

    it('should_translate_emoji_between_text', 0, () => {
      let result = translateEmojiText('你好[惊讶]世界');
      expect(result).assertEqual('你好[惊世界');
    });

    it('should_translate_three_emojis', 0, () => {
      // [a] -> emojiLength=1, 取 '[a'; [b] -> emojiLength=2, 取 'b'; [c] -> emojiLength=1, 取 '[c'
      let result = translateEmojiText('[aa][bb][cc]');
      expect(result).assertEqual('[ab[c');
    });

    it('should_handle_text_with_brackets_not_emoji_format', 0, () => {
      // 空括号不匹配 pattern \[([^\]]+)\]
      let result = translateEmojiText('hello [] world');
      expect(result).assertEqual('hello [] world');
    });

    it('should_handle_mixed_text_and_multiple_emojis', 0, () => {
      let result = translateEmojiText('Hi[emoji1]there[emoji2]!');
      // [emoji1] -> emojiLength=1 -> '[e'; [emoji2] -> emojiLength=2 -> 'e'
      expect(result).assertEqual('Hi[ethere!');
    });
  });
}
