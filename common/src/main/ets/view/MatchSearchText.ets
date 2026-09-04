import { MatchSearchTextSegments, resolveMatchSearchTextSegments } from '../utils/MatchSearchTextUtils'

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
    return this.getTextSegments().found
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
    return this.getTextSegments().startText
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
    return this.getTextSegments().endText
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
    return this.getTextSegments().matchedText
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
    const result = resolveMatchSearchTextSegments(str, keyword, length)
    return result.startText + result.matchedText + result.endText
  }

  private getTextSegments(): MatchSearchTextSegments {
    return resolveMatchSearchTextSegments(this.allText, this.searchText, 16)
  }
}
