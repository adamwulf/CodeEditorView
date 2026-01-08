//
//  AutoCharacterHandlerTests.swift
//
//
//  Tests for the auto-character handler callback system.
//

import XCTest
@testable import CodeEditorView

// MARK: - Markdown Auto-Character Handler

/// A markdown-aware auto-character handler that handles `*` for bold formatting.
///
/// Behavior:
/// - Type `*` → insert `*` with closing `*` → `*|*`
/// - Type `*` when next char is `*` → typeover → cursor moves past `*`
///
/// This creates the pattern:
/// 1. Type `*` → `*|*`
/// 2. Type `*` again → `**|` (typeover)
/// 3. Type `foo` → `**foo|`
/// 4. Type `*` → typeover if next is `*` → `**foo*|*` → nope, this inserts `*|*` again
///
/// Actually for proper bold: need to track state. Simplified version:
/// - `*` always does insertWithClosing UNLESS next char is same `*` (typeover)
///
func markdownAutoCharacterHandler(typed: Character, location: Int, text: String) -> AutoCharacterAction? {
  guard typed == "*" else { return nil }

  // Check if we should typeover (next char is *)
  if location < text.count {
    let index = text.index(text.startIndex, offsetBy: location)
    if text[index] == "*" {
      return .typeover(count: 1)
    }
  }

  // Otherwise, insert with closing
  return .insertWithClosing("*")
}

// MARK: - Tests

final class AutoCharacterHandlerTests: XCTestCase {

  // MARK: - Basic Action Tests

  func testPassthroughAction() {
    // Handler returns nil for non-* characters
    let action = markdownAutoCharacterHandler(typed: "a", location: 0, text: "")
    XCTAssertNil(action)
  }

  func testInsertWithClosingAction() {
    // Type * in empty text → should insert with closing
    let action = markdownAutoCharacterHandler(typed: "*", location: 0, text: "")
    XCTAssertEqual(action, .insertWithClosing("*"))
    // Note: This test verifies the handler returns the correct action, but does NOT test
    // that CodeView correctly positions the cursor between the typed character and the
    // closing string. Cursor positioning is handled in CodeView.insertText() and would
    // require integration testing with a real CodeView instance to verify.
  }

  func testTypeoverAction() {
    // Type * when next char is * → should typeover
    let action = markdownAutoCharacterHandler(typed: "*", location: 0, text: "*")
    XCTAssertEqual(action, .typeover(count: 1))
  }

  // MARK: - Markdown Bold Sequence Tests

  func testMarkdownBoldSequence() {
    // Simulate typing ** for bold

    // Start with empty text, cursor at 0
    var text = ""
    var cursor = 0

    // Step 1: Type first *
    let action1 = markdownAutoCharacterHandler(typed: "*", location: cursor, text: text)
    XCTAssertEqual(action1, .insertWithClosing("*"))
    // After action: text = "*|*" (where | is cursor)
    text = "**"  // Both * inserted
    cursor = 1   // Cursor between them

    // Step 2: Type second * (should typeover since next char is *)
    let action2 = markdownAutoCharacterHandler(typed: "*", location: cursor, text: text)
    XCTAssertEqual(action2, .typeover(count: 1))
    // After action: text = "**|" cursor moved past the *
    cursor = 2

    // Now we have "**" with cursor at end - ready for bold content
  }

  func testMarkdownBoldWithContent() {
    // Simulate: **foo** creation

    // After typing "**", we have "**" with cursor at position 2
    // User types "foo" normally (handler returns nil for regular chars)
    var text = "**foo"
    var cursor = 5  // After "foo"

    // Now user wants to close bold - but there's no * after cursor
    // Type first closing *
    let action1 = markdownAutoCharacterHandler(typed: "*", location: cursor, text: text)
    XCTAssertEqual(action1, .insertWithClosing("*"))
    // After: "**foo*|*"
    text = "**foo**"
    cursor = 6

    // Type second closing * (should typeover)
    let action2 = markdownAutoCharacterHandler(typed: "*", location: cursor, text: text)
    XCTAssertEqual(action2, .typeover(count: 1))
    // After: "**foo**|"
    cursor = 7

    XCTAssertEqual(text, "**foo**")
    XCTAssertEqual(cursor, 7)  // Cursor at end
  }

  func testTypeoverInMiddleOfText() {
    // Text: "hello *world* here" - cursor before the closing *
    let text = "hello *world* here"
    let cursorBeforeClosingStar = 12  // Position of the closing *

    let action = markdownAutoCharacterHandler(typed: "*", location: cursorBeforeClosingStar, text: text)
    XCTAssertEqual(action, .typeover(count: 1))
  }

  func testInsertWhenNotBeforeStar() {
    // Text: "hello world" - cursor at end, no * to typeover
    let text = "hello world"
    let cursor = text.count

    let action = markdownAutoCharacterHandler(typed: "*", location: cursor, text: text)
    XCTAssertEqual(action, .insertWithClosing("*"))
  }

  // MARK: - Edge Cases

  func testCursorAtEndOfText() {
    let text = "hello"
    let cursor = 5  // At end

    let action = markdownAutoCharacterHandler(typed: "*", location: cursor, text: text)
    XCTAssertEqual(action, .insertWithClosing("*"))
  }

  func testCursorAtStartOfText() {
    let text = "hello"
    let cursor = 0  // At start, 'h' is next char

    let action = markdownAutoCharacterHandler(typed: "*", location: cursor, text: text)
    // Next char is 'h', not '*', so insert with closing
    XCTAssertEqual(action, .insertWithClosing("*"))
  }

  func testEmptyText() {
    let text = ""
    let cursor = 0

    let action = markdownAutoCharacterHandler(typed: "*", location: cursor, text: text)
    XCTAssertEqual(action, .insertWithClosing("*"))
  }

  // MARK: - Multiple Asterisks

  func testTripleAsterisk() {
    // For bold+italic: ***text***
    // Start fresh
    var text = ""
    var cursor = 0

    // Type first * → "*|*"
    var action = markdownAutoCharacterHandler(typed: "*", location: cursor, text: text)
    XCTAssertEqual(action, .insertWithClosing("*"))
    text = "**"
    cursor = 1

    // Type second * → typeover → "**|"
    action = markdownAutoCharacterHandler(typed: "*", location: cursor, text: text)
    XCTAssertEqual(action, .typeover(count: 1))
    cursor = 2

    // Type third * → "**" + insert "*|*" → "***|*"
    action = markdownAutoCharacterHandler(typed: "*", location: cursor, text: text)
    XCTAssertEqual(action, .insertWithClosing("*"))
    text = "****"  // "**" + "*" + closing "*"
    cursor = 3

    // Type fourth * → typeover → "****|"
    action = markdownAutoCharacterHandler(typed: "*", location: cursor, text: text)
    XCTAssertEqual(action, .typeover(count: 1))
    cursor = 4

    XCTAssertEqual(text, "****")
  }

  static var allTests = [
    ("testPassthroughAction", testPassthroughAction),
    ("testInsertWithClosingAction", testInsertWithClosingAction),
    ("testTypeoverAction", testTypeoverAction),
    ("testMarkdownBoldSequence", testMarkdownBoldSequence),
    ("testMarkdownBoldWithContent", testMarkdownBoldWithContent),
    ("testTypeoverInMiddleOfText", testTypeoverInMiddleOfText),
    ("testInsertWhenNotBeforeStar", testInsertWhenNotBeforeStar),
    ("testCursorAtEndOfText", testCursorAtEndOfText),
    ("testCursorAtStartOfText", testCursorAtStartOfText),
    ("testEmptyText", testEmptyText),
    ("testTripleAsterisk", testTripleAsterisk),
  ]
}
