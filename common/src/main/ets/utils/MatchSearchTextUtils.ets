/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

export class MatchSearchTextSegments {
  found: boolean = false
  startText: string = ''
  matchedText: string = ''
  endText: string = ''
}

export function resolveMatchSearchTextSegments(
  allText: string,
  searchText: string,
  maxLength: number
): MatchSearchTextSegments {
  if (searchText.length === 0) {
    throw new Error('Keyword cannot be empty')
  }
  if (maxLength <= 0) {
    throw new Error('Length must be positive')
  }

  const result = new MatchSearchTextSegments()
  const keywordIndex = allText.toLowerCase().indexOf(searchText.toLowerCase())
  if (keywordIndex < 0) {
    return result
  }

  result.found = true
  if (searchText.length > maxLength) {
    result.startText = keywordIndex > 0 ? '...' : ''
    result.matchedText = allText.substring(keywordIndex, keywordIndex + maxLength)
    result.endText = keywordIndex + maxLength < allText.length ? '...' : ''
    return result
  }

  const remainingLength = maxLength - searchText.length
  const halfLength = Math.floor(remainingLength / 2)
  let start = Math.max(0, keywordIndex - halfLength)
  let end = Math.min(allText.length, keywordIndex + searchText.length + remainingLength - halfLength)

  if (end - start < maxLength) {
    if (start === 0) {
      end = Math.min(allText.length, start + maxLength)
    } else {
      start = Math.max(0, end - maxLength)
    }
  }

  result.startText = allText.substring(start, keywordIndex)
  result.matchedText = allText.substring(keywordIndex, keywordIndex + searchText.length)
  result.endText = allText.substring(keywordIndex + searchText.length, end)

  if (start > 0) {
    result.startText = result.startText.length > 0 ? '...' + result.startText.substring(1) : '...'
  }
  if (end < allText.length) {
    result.endText = result.endText.length > 0 ?
      result.endText.substring(0, result.endText.length - 1) + '...' : '...'
  }
  return result
}
