@ComponentV2
export struct MatchSearchText {
  @Param allText: string = ""
  @Param searchText: string = ""
  @Param fontSize: number = 14
  @Param normalFontColor: ResourceColor = "#333333"
  @Param highlightFontColor: ResourceColor = "#337EFF"

  startOfSearchText() {
    return this.allText?.indexOf(this.searchText)
  }

  endOfSearchText() {
    return this.startOfSearchText() + this.searchText.length
  }

  startText() {
    const result = this.extractKeywordCenteredSubstring(this.allText, this.searchText, 16)
    const index = result.indexOf(this.searchText)
    const start = result.substring(0, index)
    return start
  }

  endText() {
    const result = this.extractKeywordCenteredSubstring(this.allText, this.searchText, 16)
    const index = result.indexOf(this.searchText)
    const end = result.substring(index + this.searchText.length, result.length)
    return end
  }

  build() {
    Text() {
      Span(this.startText())
        .fontSize(this.fontSize)
        .fontColor(this.normalFontColor)

      Span(this.searchText)
        .fontColor(this.highlightFontColor)
        .fontSize(this.fontSize)

      Span(this.endText())
        .fontSize(this.fontSize)
        .fontColor(this.normalFontColor)

    }
    .maxLines(1)
    .textOverflow({
      overflow: TextOverflow.Ellipsis
    })
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

    const keywordIndex = str.indexOf(keyword);
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