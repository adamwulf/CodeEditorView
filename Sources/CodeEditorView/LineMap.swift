//
//  LineMap.swift
//  
//
//  Created by Manuel M T Chakravarty on 29/09/2020.
//

import Foundation


/// Keeps track of the character ranges and parametric `LineInfo` for all lines in a string.
///
struct LineMap<LineInfo> {

  /// The character range of the line in the underlying string together with additional information if available.
  ///
  typealias OneLine = (range: NSRange, info: LineInfo?)

  /// Box for a cached lookup to allow sharing across copies of the struct and non-mutating updates.
  ///
  private class LookupCache {
    var index: Int = -1
    var line: Int = -1
  }

  /// The start positions of all lines.
  ///
  /// NB: This array always contains one extra element at the end, which is the end-of-string position (sentinel).
  ///
  private(set) var lineStarts: [Int] = []

  /// The information for each line.
  ///
  private(set) var lineInfos: [LineInfo?] = []

  /// The cached lookup information.
  ///
  private var lookupCache = LookupCache()


  /// MARK: -
  /// MARK: Initialisation

  /// Direct initialisation for testing.
  ///
  init(lines: [OneLine]) {
    for line in lines {
      lineStarts.append(line.range.location)
      lineInfos.append(line.info)
    }
    lineStarts.append(lines.last?.range.max ?? 0)
  }

  /// Initialise a line map with the string to be mapped.
  ///
  init(string: String) {
    let (starts, infos) = linesOf(string: string)
    self.lineStarts = starts
    self.lineInfos = infos
  }


  // MARK: -
  // MARK: Queries

  /// Safe lookup of the information pertaining to a given line.
  ///
  /// - Parameter line: The zero-based line number to look up.
  /// - Returns: The description of the given line if it is within the valid range of the line map.
  ///
  func lookup(line: Int) -> OneLine? {
    guard line >= 0 && line < lineInfos.count else { return nil }
    return (range: NSRange(location: lineStarts[line], length: lineStarts[line+1] - lineStarts[line]), info: lineInfos[line])
  }

  /// Return the character range covered by the given range of lines. Safely handles out of bounds situations.
  ///
  /// NB: Line numbers are zero-based.
  ///
  func charRangeOf(lines: Range<Int>) -> NSRange {
    let startLine = lines.first ?? 0,
        endLine   = lines.last ?? 0
    let startLocation = (startLine >= 0 && startLine < lineInfos.count) ? lineStarts[startLine] : 0,
        endLocation   = (endLine >= 0 && endLine < lineInfos.count) ? lineStarts[endLine+1] : startLocation
    return NSRange(location: startLocation, length: endLocation - startLocation)
  }

  /// Determine the zero-based line number of the line containing the characters at the given string index. (Safe to be
  /// called with an out of bounds index.)
  ///
  /// - Parameter index: The string index of the characters whose line we want to determine.
  /// - Returns: The zero-based line number containing the indexed character if the index is within the bounds of the
  ///     string.
  ///
  /// - Complexity: Optimized with a temporal cache for $O(1)$ sequential access and $O(\log n)$ binary search on 
  ///               tightly packed integers for maximum cache locality.
  ///
  func lineContaining(index: Int) -> Int? {
    // 1. Thread-safe self-validating cache hit
    let cachedLine = lookupCache.line
    if cachedLine >= 0 && cachedLine < lineInfos.count {
      // Check current cached line
      if index >= lineStarts[cachedLine] && index < lineStarts[cachedLine + 1] {
        return cachedLine
      }
      
      // Check next line (common for forward scans)
      let nextLine = cachedLine + 1
      if nextLine < lineInfos.count && index >= lineStarts[nextLine] && index < lineStarts[nextLine + 1] {
        lookupCache.index = index
        lookupCache.line = nextLine
        return nextLine
      }
    }

    // 2. Binary search on tightly packed lineStarts
    let result = lineStarts.withUnsafeBufferPointer { buffer -> Int? in
      var lo = 0
      var hi = buffer.count - 1 // Exclude the sentinel
      
      while lo < hi {
        let mid = lo + (hi - lo) >> 1
        if buffer[mid] <= index { lo = mid + 1 }
        else { hi = mid }
      }
      
      let line = lo - 1
      if line >= 0 && line < buffer.count - 1 {
        if index >= buffer[line] && index < buffer[line + 1] {
          return line
        }
      }
      return nil
    }

    // 3. Update cache
    if let r = result {
      lookupCache.index = index
      lookupCache.line = r
    }
    return result
  }

  /// Determine the zero-based line number that contains the cursor position specified by the given string index. (Safe
  /// to be called with an out of bounds index.)
  ///
  /// Corresponds to `lineContaining(index:)`, but also handles the index just after the last valid string index — i.e.,
  /// the end-of-string insertion point.
  ///
  /// - Parameter index: The string index of the cursor position whose line we want to determine.
  /// - Returns: The zero-based line number containing the given cursor poisition if the index is within the bounds of
  ///     the string or just beyond.
  ///
  /// - Complexity: This functions asymptotic complexity is logarithmic in the number of lines contained in the line
  ///               map.
  ///
  func lineOf(index: Int) -> Int? {
    if lineStarts.last == index && !lineInfos.isEmpty { return lineInfos.count - 1 }
    else { return lineContaining(index: index) }
  }

  /// Determine the zero-based line that contains the cursor position specified by the given string index together with
  /// the line position. (Safe to be called with an out of bounds index.)
  ///
  /// - Parameter index: The string index of the cursor position whose line we want to determine.
  /// - Returns: The zero-based line containing the given cursor poisition together with line position if the index is
  ///     within the bounds of the string or just beyond.
  ///
  /// - Complexity: This functions asymptotic complexity is logarithmic in the number of lines contained in the line
  ///               map.
  ///
  func lineAndPositionOf(index: Int) -> (line: Int, position: Int)? {
    guard let line  = lineOf(index: index)
    else { return nil }

    return (line: line, position: index - lineStarts[line])
  }

  /// Given a character range, return the smallest zero-based line range that includes the characters. Deal with out of
  /// bounds conditions by clipping to the front and end of the line range, respectively.
  ///
  /// - Parameter range: The character range for which we want to know the line range.
  /// - Returns: The smallest range of lines that includes all characters in the given character range. The start value
  ///     of that range is greater or equal 0.
  ///
  /// There are two special cases:
  /// - If (1) the range is empty, (2) its location (= insertion) at the end of the string, and (3) the text ends on a
  ///   trailing empty line, the result is the trailing line on its own.
  /// - If the character range is of length zero, we return the line of the start location. We do that also if the start
  ///   location is just behind the last character of the text.
  ///
  func linesContaining(range: NSRange) -> Range<Int> {
    let
      start         = range.location < 0 ? 0 : range.location,
      end           = range.length <= 0 ? start : range.max - 1,
      startLine     = lineOf(index: start),
      endLine       = lineContaining(index: end),
      lastLine      = lineInfos.count - 1

    if let startLine = startLine {

      if range.length < 0 { return startLine..<startLine }
      else if range.location == lineStarts[lastLine] && range.length == (lineStarts.last! - lineStarts[lastLine]) { 
        return Range<Int>(lastLine...lastLine) 
      }
      else { return Range<Int>(startLine...(endLine ?? lastLine)) }

    } else {

      if range.location < 0 { return 0..<0 } else { return lastLine..<lastLine }

    }
  }

  /// Given a character range, return the smallest zero-based line range that includes the characters plus maybe a
  /// trailing empty line. Deal with out of bounds conditions by clipping to the front and end of the line range,
  /// respectively.
  ///
  /// - Parameter range: The character range for which we want to know the line range.
  /// - Returns: The smallest range of lines that includes all characters in the given character range. The start value
  ///     of that range is greater or equal 0.
  ///
  /// There are two special cases:
  /// - If the character range extends until the end of the text and the last line is a trailing empty line, that
  ///   trailing empty line is also included in the result. This behaviour distinguished the present function from
  ///   `linesContaining(range:)`, on which it is based.
  /// - If the character range is of length zero, we return the line of the start location. We do that also if the start
  ///   location is just behind the last character of the text.
  ///
  func linesOf(range: NSRange) -> Range<Int> {
    let lastLine      = lineInfos.count - 1

    if range.max == lineStarts[lastLine] && (lineStarts.last! - lineStarts[lastLine]) == 0 {

      // Range reaches to the end of text => extend 'endLine' to 'lastLine'
      return Range<Int>(linesContaining(range: range).startIndex...lastLine)

    } else {

      return linesContaining(range: range)

    }
  }

  /// Compute the lines affected by an editing activity.
  ///
  /// - Parameters:
  ///   - editedRange: The character range that was affected by editing (after the edit).
  ///   - delta: The length increase of the edited string (negative if it got shorter).
  /// - Returns: The zero-based range of lines (of the original string) that is affected by the editing action.
  ///
  func linesAffected(by editedRange: NSRange, changeInLength delta: Int) -> Range<Int> {

    if let shiftedRange = editedRange.shifted(endBy: -delta) {

      // To compute the line range, we extend the character range by one extra character. This is crucial as, if the
      // edited range ends on a newline, this may insert a new line break, which means, line *after* the new line break
      // also belongs to the affected lines.
      let oldStringRange = NSRange(location: 0, length: lineStarts.last ?? 0)
      return linesOf(range: extend(range: shiftedRange, clippingTo: oldStringRange))

    } else { return 0..<0 }
  }

  // MARK: -
  // MARK: Editing

  /// Set the info field for the given line (starting from 0).
  ///
  /// - Parameters:
  ///   - line: The zero-based line whose info field ought to be set.
  ///   - info: The new info value for that line.
  ///
  ///   NB: Ignores lines that do not exist.
  ///
  mutating func setInfoOf(line: Int, to info: LineInfo?) {
    guard line >= 0 && line < lineInfos.count else { return }

    lineInfos[line] = info
  }

  /// Update the line map given the specified editing activity of the underlying string. It resets the info field for
  /// each affected line.
  ///
  /// - Parameters:
  ///   - string: The string after editing.
  ///   - editedRange: The character range that was affected by editing (after the edit).
  ///   - delta: The length increase of the edited string (negative if it got shorter).
  ///
  /// NB: The line after the `editedRange` will be updated (and info fields be invalidated) if the `editedRange` ends on
  ///     a newline.
  ///
  mutating func updateAfterEditing(string: String, range editedRange: NSRange, changeInLength delta: Int) {

    // To compute line ranges, we extend all character ranges by one extra character. This is crucial as, if the
    // edited range ends on a newline, this may insert a new line break, which means, we also need to update the line
    // *after* the new line break.
    //
    let nsString            = string as NSString,
        newStringRange      = NSRange(location: 0, length: nsString.length),
        oldLinesRange       = linesAffected(by: editedRange, changeInLength: delta),  // NB: `linesAffected` extends itself
        extendedEditedRange = extend(range: editedRange, clippingTo: newStringRange),
        newLinesRange       = nsString.lineRange(for: extendedEditedRange),
        newLinesString      = nsString.substring(with: newLinesRange),
        (newStarts, newInfos) = linesOf(string: newLinesString)
    
    // Shift new starts to be relative to the string
    let shiftedNewStarts = newStarts.map { $0 + newLinesRange.location }

    // If the newly inserted text ends on a new line, we need to remove the empty trailing line in the new lines array
    // unless the range of those new lines extends until the end of the string.
    let dropEmptyNewLine = (newStarts.last! - newStarts[newStarts.count - 2]) == 0 && oldLinesRange.last != lineInfos.count - 1,
        finalNewStarts   = dropEmptyNewLine ? Array(shiftedNewStarts.dropLast()) : shiftedNewStarts,
        finalNewInfos    = dropEmptyNewLine ? Array(newInfos.dropLast()) : newInfos

    lineStarts.replaceSubrange(oldLinesRange.startIndex..<(oldLinesRange.endIndex + 1), with: finalNewStarts)
    lineInfos.replaceSubrange(oldLinesRange, with: finalNewInfos)

    // All ranges after the edited range of lines need to be adjusted.
    //
    for i in oldLinesRange.startIndex.advanced(by: finalNewInfos.count) + 1 ..< lineStarts.count {
      lineStarts[i] += delta
    }
    
    // Invalidate the cache since the underlying data has changed.
    lookupCache = LookupCache()
  }

  // MARK: -
  // MARK: Helpers

  /// Extract the corresponding array of line ranges out of the given string.
  ///
  private func linesOf(string: String) -> (starts: [Int], infos: [LineInfo?]) {
    let nsString = string as NSString

    var starts: [Int] = []
    var infos: [LineInfo?] = []

    // Enumerate all lines in `nsString`, adding them to the `resultingLines`.
    //
    var currentIndex = 0
    while currentIndex < nsString.length {

      let currentRange = nsString.lineRange(for: NSRange(location: currentIndex, length: 0))
      starts.append(currentRange.location)
      infos.append(nil)
      currentIndex = currentRange.max

    }

    // Check if there is an empty last line (due to a linebreak being at the end of the text), and if so, add that
    // extra empty line to the `resultingLines` as well.
    //
    let lastRange = nsString.lineRange(for: NSRange(location: nsString.length, length: 0))
    if lastRange.length == 0 {
      starts.append(lastRange.location)
      infos.append(nil)
    }
    
    // Always add the total length as a sentinel
    starts.append(nsString.length)

    return (starts: starts, infos: infos)
  }

  private func extend(range: NSRange, clippingTo stringRange: NSRange) -> NSRange {
    return
      range.location == stringRange.max
      ? NSRange(location: range.location, length: 0)
      : NSIntersectionRange(NSRange(location: range.location, length: range.length + 1), stringRange)
  }
}
