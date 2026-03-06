@ComponentV2
export struct MatchSearchText {
  @Param allText: string = ""
  @Param searchText: string = ""
  @Param fontSize: number | Resource = 14
  @Param normalFontColor: ResourceColor = "#333333"
  @Param highlightFontColor: ResourceColor = "#337EFF"
  @Param showFullText: boolean = false

  // 检查是否能在原文中找到搜索关键词
  canFindKeyword(): boolean {
    if (!this.allText || !this.searchText) {
      return false
    }
    return this.allText.toLowerCase().indexOf(this.searchText.toLowerCase()) >= 0
  }

  startOfSearchText() {
    return this.allText?.toLowerCase().indexOf(this.searchText.toLowerCase())
  }

  endOfSearchText() {
    return this.startOfSearchText() + this.searchText.length
  }

  startText() {
    // showFullText 为 true 时不做截断，直接返回关键词前的完整文本
    if (this.showFullText) {
      const index = this.allText.toLowerCase().indexOf(this.searchText.toLowerCase())
      if (index >= 0) {
        return this.allText.substring(0, index)
      }
      return this.allText
    }
    const result = this.extractKeywordCenteredSubstring(this.allText, this.searchText, 16)
    const index = result.toLowerCase().indexOf(this.searchText.toLowerCase())
    const start = result.substring(0, index)
    return start
  }

  endText() {
    // showFullText 为 true 时不做截断，直接返回关键词后的完整文本
    if (this.showFullText) {
      const index = this.allText.toLowerCase().indexOf(this.searchText.toLowerCase())
      if (index >= 0) {
        return this.allText.substring(index + this.searchText.length)
      }
      return ""
    }
    const result = this.extractKeywordCenteredSubstring(this.allText, this.searchText, 16)
    const index = result.toLowerCase().indexOf(this.searchText.toLowerCase())
    const end = result.substring(index + this.searchText.length, result.length)
    return end
  }

  // 获取实际匹配的文本（保持原始大小写）
  getMatchedText() {
    // showFullText 为 true 时直接从原始文本中获取匹配文本
    if (this.showFullText) {
      const index = this.allText.toLowerCase().indexOf(this.searchText.toLowerCase())
      if (index >= 0) {
        return this.allText.substring(index, index + this.searchText.length)
      }
      return this.searchText
    }
    const result = this.extractKeywordCenteredSubstring(this.allText, this.searchText, 16)
    const index = result.toLowerCase().indexOf(this.searchText.toLowerCase())
    if (index >= 0) {
      return result.substring(index, index + this.searchText.length)
    }
    return this.searchText
  }

  build() {
    // 如果找不到关键词匹配，直接展示原文本，不进行高亮拼接
    if (!this.canFindKeyword()) {
      Text(this.allText)
        .fontSize(this.fontSize)
        .fontColor(this.normalFontColor)
        .maxLines(this.showFullText ? 100 : 1)
        .textOverflow({
          overflow: TextOverflow.Ellipsis
        })
    } else {
      Text() {
        Span(this.startText())
          .fontSize(this.fontSize)
          .fontColor(this.normalFontColor)

        Span(this.getMatchedText())
          .fontColor(this.highlightFontColor)
          .fontSize(this.fontSize)

        Span(this.endText())
          .fontSize(this.fontSize)
          .fontColor(this.normalFontColor)

      }
      .maxLines(this.showFullText ? 100 : 1)
      .textOverflow({
        overflow: TextOverflow.Ellipsis
      })
    }
  }

  extractKeywordCenteredSubstring(str: string, keyword: string, length: number): string {
    if (keyword.length === 0) {
      throw new Error("Keyword cannot be empty");
    }
    if (length <= 0) {
      throw new Error("Length must be positive");
    }
    if (keyword.length > length) {
      // 如果 keyword 本身比 length 长，返回 keyword 的前 length 个字符
      return keyword.substring(0, length);
    }

    // 使用大小写不敏感的搜索
    const keywordIndex = str.toLowerCase().indexOf(keyword.toLowerCase());
    if (keywordIndex === -1) {
      return ""; // 或 throw new Error("Keyword not found");
    }

    const remainingLength = length - keyword.length;
    const halfLength = Math.floor(remainingLength / 2);

    // 计算前后可用的字符数
    const beforeStart = Math.max(0, keywordIndex - halfLength);
    const afterEnd = keywordIndex + keyword.length +
      (remainingLength - halfLength);

    // 确保不越界
    const start = Math.max(0, beforeStart);
    const end = Math.min(str.length, afterEnd);

    let result = str.substring(start, end);

    // 如果结果长度不够（比如靠近字符串边界），从另一端补足
    if (result.length < length) {
      if (start === 0) {
        // 如果前面已经到头了，从后面补
        const extraNeeded = length - result.length;
        result = str.substring(start, Math.min(str.length, end + extraNeeded));
      } else {
        // 如果后面到头了，从前面补
        const extraNeeded = length - result.length;
        result = str.substring(Math.max(0, start - extraNeeded), end);
      }
    }

    if (start > 0) {
      result = '...' + result.substring(1)
    }

    if (end < str.length) {
      result = result.substring(0, result.length - 1) + "...";
    }

    return result;
  }
}