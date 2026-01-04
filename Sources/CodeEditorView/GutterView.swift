//
//  GutterView.swift
//  
//
//  Created by Manuel M T Chakravarty on 23/09/2020.
//

import os

import Rearrange

import LanguageSupport


private let logger = Logger(subsystem: "org.justtesting.CodeEditorView", category: "GutterView")


#if os(iOS) || os(visionOS)

// MARK: -
// MARK: UIKit version

import UIKit


private let fontDescriptorFeatureIdentifier = OSFontDescriptor.FeatureKey.type
private let fontDescriptorTypeIdentifier    = OSFontDescriptor.FeatureKey.selector


#elseif os(macOS)


// MARK: -
// MARK: AppKit version

import AppKit


private let fontDescriptorFeatureIdentifier = OSFontDescriptor.FeatureKey.typeIdentifier
private let fontDescriptorTypeIdentifier    = OSFontDescriptor.FeatureKey.selectorIdentifier

#endif


// MARK: -
// MARK: Shared code

private let lineNumberColour = OSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)

// MARK: - Cached resources for gutter drawing

/// Cache for expensive font and attribute computations
private struct GutterDrawingCache {
  let font: OSFont
  let textAttributesDefault: [NSAttributedString.Key: Any]
  let textAttributesSelected: [NSAttributedString.Key: Any]
  let fontSize: CGFloat
  let textColour: OSColor

  init(fontSize: CGFloat, textColour: OSColor) {
    self.fontSize = fontSize
    self.textColour = textColour

    let desc = OSFont.systemFont(ofSize: fontSize).fontDescriptor.addingAttributes(
      [ OSFontDescriptor.AttributeName.featureSettings:
          [
            [
              fontDescriptorFeatureIdentifier: kNumberSpacingType,
              fontDescriptorTypeIdentifier: kMonospacedNumbersSelector,
            ],
            [
              fontDescriptorFeatureIdentifier: kStylisticAlternativesType,
              fontDescriptorTypeIdentifier: kStylisticAltOneOnSelector,  // alt 6 and 9
            ],
            [
              fontDescriptorFeatureIdentifier: kStylisticAlternativesType,
              fontDescriptorTypeIdentifier: kStylisticAltTwoOnSelector,  // alt 4
            ]
          ]
      ]
    )
    #if os(iOS) || os(visionOS)
    self.font = OSFont(descriptor: desc, size: 0)
    #elseif os(macOS)
    self.font = OSFont(descriptor: desc, size: 0) ?? OSFont.systemFont(ofSize: 0)
    #endif

    let lineNumberStyle = NSMutableParagraphStyle()
    lineNumberStyle.alignment = .right
    lineNumberStyle.tailIndent = -fontSize / 11

    self.textAttributesDefault = [
      .font: font,
      .foregroundColor: lineNumberColour,
      .paragraphStyle: lineNumberStyle,
      .kern: NSNumber(value: Float(-fontSize / 11))
    ]
    self.textAttributesSelected = [
      .font: font,
      .foregroundColor: textColour,
      .paragraphStyle: lineNumberStyle,
      .kern: NSNumber(value: Float(-fontSize / 11))
    ]
  }
}

/// Pre-computed NSString objects for common line numbers (1-1000)
/// Avoids repeated string interpolation and NSString bridging in draw loop
private let precomputedLineNumberStrings: [NSString] = {
  (1...1000).map { NSString(format: "%d", $0) }
}()

/// Get pre-computed NSString for line number, or create one for larger numbers
@inline(__always)
private func lineNumberString(for lineNumber: Int) -> NSString {
  if lineNumber >= 1 && lineNumber <= 1000 {
    return precomputedLineNumberStrings[lineNumber - 1]
  }
  return "\(lineNumber)" as NSString
}

final class GutterView: OSView {

  /// The text view that this gutter belongs to.
  ///
  weak var textView: OSTextView?

  /// The code storage containing the text accompanied by this gutter.
  ///
  var codeStorage: CodeStorage

  /// The current code editor theme
  ///
  var theme: Theme

  /// Accessor for the associated text view's message views.
  ///
  let getMessageViews: () -> MessageViews

  /// Determines whether this gutter is for a main code view or for the minimap of a code view.
  ///
  let isMinimapGutter: Bool

  /// Cached drawing resources (font, attributes) - invalidated when theme changes
  private var drawingCache: GutterDrawingCache?

  /// Create and configure a gutter view for the given text view. The gutter view is transparent, so that we can place
  /// highlight views behind it.
  ///
  init(frame: CGRect,
       textView: OSTextView,
       codeStorage: CodeStorage,
       theme: Theme,
       getMessageViews: @escaping () -> MessageViews,
       isMinimapGutter: Bool)
  {
    self.textView        = textView
    self.codeStorage     = codeStorage
    self.theme           = theme
    self.getMessageViews = getMessageViews
    self.isMinimapGutter = isMinimapGutter
    super.init(frame: frame)
#if os(iOS) || os(visionOS)
    isOpaque = false
#endif
  }

  @available(*, unavailable)
  required init(coder: NSCoder) {
    fatalError("CodeEditorView.GutterView.init(coder:) not implemented")
  }

  /// Returns cached drawing resources, creating them if needed or if theme changed
  private func getDrawingCache() -> GutterDrawingCache {
    if let cache = drawingCache,
       cache.fontSize == theme.fontSize,
       cache.textColour == theme.textColour {
      return cache
    }
    let cache = GutterDrawingCache(fontSize: theme.fontSize, textColour: theme.textColour)
    drawingCache = cache
    return cache
  }

#if os(macOS)
  // Use the coordinate system of the associated text view.
  override var isFlipped: Bool { textView?.isFlipped ?? false }
#endif
}

extension GutterView {

  var optTextLayoutManager:  NSTextLayoutManager?   { textView?.optTextLayoutManager }
  var optTextContentStorage: NSTextContentStorage?  { textView?.optTextContentStorage }
  var optTextContainer:      NSTextContainer?       { textView?.optTextContainer }
  var optLineMap:            LineMap<LineInfo>?     { (codeStorage.delegate as? CodeStorageDelegate)?.lineMap }

  // MARK: -
  // MARK: Gutter notifications

  /// Notifies the gutter view that a range of characters will be redrawn by the layout manager or that there are
  /// selection status changes; thus, the corresponding gutter area might require redrawing, too.
  ///
  /// - Parameters:
  ///   - charRange: The invalidated range of characters. It will be trimmed to be within the valid character range of
  ///     the underlying text storage. If this argument is `nil`, the entire gutter view is invalidated.
  ///
  /// We invalidate the area corresponding to entire paragraphs. This makes a difference in the presence of line
  /// breaks.
  ///
  func invalidateGutter(for charRange: NSRange? = nil) {
    guard let charRange else {
#if os(macOS)
      needsDisplay = true
#else
      setNeedsDisplay()
#endif
      return
    }

    guard let textLayoutManager   = optTextLayoutManager,
          let textContentStorage  = textLayoutManager.textContentManager as? NSTextContentStorage,
          let viewPortRange       = textLayoutManager.textViewportLayoutController.viewportRange,
          let viewPortRangeExt    = textContentStorage.range(for: viewPortRange).shifted(endBy: 1),
          // with the above shift we allow for an insertion point at the end of the text
          let charRangeInViewPort = viewPortRangeExt.intersection(charRange),
          let string              = textContentStorage.textStorage?.string as NSString?
    else { return }


    // We call `paragraphRange(for:_)` safely by boxing `charRange` to the allowed range.
    let extendedCharRange = string.paragraphRange(for: charRangeInViewPort.clamped(to: string.length))

    if let textRange              = textContentStorage.textRange(for: extendedCharRange),
       let (y: y, height: height) = textLayoutManager.textLayoutFragmentExtent(for: textRange),
        height > 0
    {
      setNeedsDisplay(gutterRectFrom(y: y, height: height))
    }

    if charRange.max == string.length,
       let endLocation        = textContentStorage.textLocation(for: charRange.max),
       let textLayoutFragment = textLayoutManager.textLayoutFragment(for: endLocation),
       let textRect           = textLayoutFragment.layoutFragmentFrameExtraLineFragment
    {
      setNeedsDisplay(gutterRectForLineNumbersFrom(textRect: textRect))
    }
  }

  // MARK: -
  // MARK: Gutter drawing

  override func draw(_ rect: CGRect) {
    guard let textLayoutManager  = optTextLayoutManager,
          let textContentStorage = optTextContentStorage,
          let lineMap            = optLineMap
    else { return }

    // We can't draw the gutter without having layout information for the viewport.
    let viewPortBounds = textLayoutManager.textViewportLayoutController.viewportBounds
    textLayoutManager.ensureLayout(for: viewPortBounds)

    // Use cached font and attributes (avoids expensive font descriptor creation per draw)
    let cache = getDrawingCache()

    let selectedLines = textView?.selectedLines ?? Set(1..<2)

    // We always enumerate all lines that are in the viewport (but we don't draw if they fall outside of `rect`).
    let textRange      = textLayoutManager.textViewportLayoutController.viewportRange
                         ?? textLayoutManager.documentRange,
        characterRange = textContentStorage.range(for: textRange)

    // Draw line numbers unless this is a gutter for a minimap
    if !isMinimapGutter {

      let lineRange = lineMap.linesOf(range: characterRange)

      for line in lineRange {  // NB: These are zero-based line numbers

        guard let lineInfo = lineMap.lookup(line: line),
              let lineStartLocation  = textContentStorage.textLocation(for: lineInfo.range.location),
              let textLayoutFragment = textLayoutManager.textLayoutFragment(for: lineStartLocation)
        else { continue }

        let gutterRect = gutterRectForLineNumbersFrom(textRect:
                                                        textLayoutFragment.layoutFragmentFrameWithoutExtraLineFragment),
           attributes  = selectedLines.contains(line) ? cache.textAttributesSelected : cache.textAttributesDefault
        if gutterRect.intersects(rect) {
          lineNumberString(for: line + 1).draw(in: gutterRect, withAttributes: attributes)
        }
      }

      // If we are at the end, we also draw a line number for the extra line fragement if that exists
      if lineRange.endIndex == lineMap.lineInfos.count,
         let endLocation        = textContentStorage.location(textRange.endLocation, offsetBy: -1),
         let textLayoutFragment = textLayoutManager.textLayoutFragment(for: endLocation),
         let textRect           = textLayoutFragment.layoutFragmentFrameExtraLineFragment
      {

        let gutterRect = gutterRectForLineNumbersFrom(textRect: textRect),
            attributes = selectedLines.contains(lineRange.endIndex - 1)
                         ? cache.textAttributesSelected : cache.textAttributesDefault
        if gutterRect.intersects(rect) {
          lineNumberString(for: lineMap.lineInfos.count).draw(in: gutterRect, withAttributes: attributes)
        }

      } else if textRange.isEmpty {  // Empty document (i.e., there is no layout fragment)

        let firstTextRect = CGRect(x: 0, y: 0, width: 0, height: cache.font.lineHeight),
            gutterRect    = gutterRectForLineNumbersFrom(textRect: firstTextRect)
        if gutterRect.intersects(rect) {
          lineNumberString(for: 1).draw(in: gutterRect, withAttributes: cache.textAttributesSelected)
        }
      }
    }

  }
}

extension GutterView {

  /// Compute the full width rectangle in the gutter from its vertical extent.
  ///
  private func gutterRectFrom(y: CGFloat, height: CGFloat) -> CGRect {
    return CGRect(origin: CGPoint(x: 0, y: y + (textView?.textContainerOrigin.y ?? 0)),
                  size: CGSize(width: frame.size.width, height: height))
  }

  /// Compute the line number glyph rectangle in the gutter from a text container rectangle, such that they both have
  /// the same vertical extension.
  ///
  private func gutterRectForLineNumbersFrom(textRect: CGRect) -> CGRect {
    let gutterRect = gutterRectFrom(y: textRect.minY, height: textRect.height)
    return CGRect(x: gutterRect.origin.x + gutterRect.size.width * 1/7,
                  y: gutterRect.origin.y,
                  width: gutterRect.size.width * 5/7,
                  height: gutterRect.size.height)
  }

  /// Compute the full width rectangle in the text container from a gutter rectangle, such that they both have the same
  /// vertical extension.
  ///
  private func textRectFrom(gutterRect: CGRect) -> CGRect {
    let containerWidth = optTextContainer?.size.width ?? 0
    return CGRect(origin: CGPoint(x: frame.size.width, y: gutterRect.origin.y - (textView?.textContainerOrigin.y ?? 0)),
                  size: CGSize(width: containerWidth - frame.size.width, height: gutterRect.size.height))
  }
}
