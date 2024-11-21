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

  build() {
    Text() {
      Span(this.allText.substring(0, this.startOfSearchText()))
        .fontSize(this.fontSize)
        .fontColor(this.normalFontColor)

      Span(this.searchText)
        .fontColor(this.highlightFontColor)
        .fontSize(this.fontSize)

      Span(this.allText.substring(this.endOfSearchText(), this.allText.length))
        .fontSize(this.fontSize)
        .fontColor(this.normalFontColor)

    }
    .maxLines(1)
    .textOverflow({
      overflow: TextOverflow.Ellipsis
    })
  }
}