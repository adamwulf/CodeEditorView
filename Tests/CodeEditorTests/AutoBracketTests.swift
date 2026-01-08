//
//  AutoBracketTests.swift
//
//
//  Tests for auto-bracket insertion and deletion functionality.
//

import XCTest
@testable import CodeEditorView
@testable import LanguageSupport

final class AutoBracketTests: XCTestCase {

  // MARK: - Helper

  /// Creates a CodeStorage with CodeStorageDelegate for Swift language.
  private func makeCodeStorage() -> (CodeStorage, CodeStorageDelegate) {
    let codeStorageDelegate = CodeStorageDelegate(with: .swift(), setText: { _ in })
    let codeStorage = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate
    return (codeStorage, codeStorageDelegate)
  }

  // MARK: - Auto-Insertion Tests

  func testRoundBracketAutoInsertion() throws {
    let (codeStorage, _) = makeCodeStorage()

    // Start with "func"
    codeStorage.setAttributedString(NSAttributedString(string: "func"))
    XCTAssertEqual(codeStorage.string, "func")

    // Type "(" at position 4 - immediately inserts ")" too
    codeStorage.replaceCharacters(in: NSRange(location: 4, length: 0), with: "(")
    XCTAssertEqual(codeStorage.string, "func()")

    // Type "x" at position 5 (between the brackets)
    codeStorage.replaceCharacters(in: NSRange(location: 5, length: 0), with: "x")
    XCTAssertEqual(codeStorage.string, "func(x)")
  }

  func testSquareBracketAutoInsertion() throws {
    let (codeStorage, _) = makeCodeStorage()

    // Start with "arr"
    codeStorage.setAttributedString(NSAttributedString(string: "arr"))
    XCTAssertEqual(codeStorage.string, "arr")

    // Type "[" at position 3 - immediately inserts "]" too
    codeStorage.replaceCharacters(in: NSRange(location: 3, length: 0), with: "[")
    XCTAssertEqual(codeStorage.string, "arr[]")

    // Type "0" at position 4 (between the brackets)
    codeStorage.replaceCharacters(in: NSRange(location: 4, length: 0), with: "0")
    XCTAssertEqual(codeStorage.string, "arr[0]")
  }

  func testCurlyBracketAutoInsertion() throws {
    let (codeStorage, _) = makeCodeStorage()

    // Start with "if true "
    codeStorage.setAttributedString(NSAttributedString(string: "if true "))
    XCTAssertEqual(codeStorage.string, "if true ")

    // Type "{" at position 8
    codeStorage.replaceCharacters(in: NSRange(location: 8, length: 0), with: "{")
    XCTAssertEqual(codeStorage.string, "if true {")

    // Type " " at position 9 - this should trigger auto-insertion of "}"
    codeStorage.replaceCharacters(in: NSRange(location: 9, length: 0), with: " ")
    XCTAssertEqual(codeStorage.string, "if true { }")
  }

  func testNestedCommentAutoInsertion() throws {
    let (codeStorage, _) = makeCodeStorage()

    // Start with empty
    codeStorage.setAttributedString(NSAttributedString(string: ""))

    // Type "/" at position 0
    codeStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "/")
    XCTAssertEqual(codeStorage.string, "/")

    // Type "*" at position 1 - this creates "/*" token
    // Note: Auto-completion does NOT trigger here because the "/" and "/*" tokens overlap
    codeStorage.replaceCharacters(in: NSRange(location: 1, length: 0), with: "*")
    XCTAssertEqual(codeStorage.string, "/*")

    // Type " " at position 2 - this should trigger auto-insertion of "*/"
    // because the previous token (nestedCommentOpen) is an opening bracket
    codeStorage.replaceCharacters(in: NSRange(location: 2, length: 0), with: " ")
    XCTAssertEqual(codeStorage.string, "/* */")
  }

  func testNestedCommentAutoDeletionNotSupported() throws {
    let (codeStorage, _) = makeCodeStorage()

    // Start with "/* */" - adjacent comment brackets
    codeStorage.setAttributedString(NSAttributedString(string: "/* */"))
    XCTAssertEqual(codeStorage.string, "/* */")

    // Delete "/" at position 0 - should NOT auto-delete "*/" because
    // auto-deletion only works for single-character brackets
    codeStorage.replaceCharacters(in: NSRange(location: 0, length: 1), with: "")
    XCTAssertEqual(codeStorage.string, "* */")
  }

  func testNestedBracketAutoInsertion() throws {
    let (codeStorage, _) = makeCodeStorage()

    // Start with "func"
    codeStorage.setAttributedString(NSAttributedString(string: "func"))

    // Type "(" at position 4 - immediately inserts ")" too
    codeStorage.replaceCharacters(in: NSRange(location: 4, length: 0), with: "(")
    XCTAssertEqual(codeStorage.string, "func()")

    // Type "(" again at position 5 (between the brackets) - immediately inserts another "()"
    // The outer ) gets pushed, resulting in properly nested brackets
    codeStorage.replaceCharacters(in: NSRange(location: 5, length: 0), with: "(")
    XCTAssertEqual(codeStorage.string, "func(())")
  }

  func testNoAutoInsertionWhenTypingMatchingClose() throws {
    let (codeStorage, _) = makeCodeStorage()

    // Start with "func"
    codeStorage.setAttributedString(NSAttributedString(string: "func"))

    // Type "(" at position 4 - immediately inserts ")" too
    codeStorage.replaceCharacters(in: NSRange(location: 4, length: 0), with: "(")
    XCTAssertEqual(codeStorage.string, "func()")

    // Type ")" at position 5 - this is where cursor would be, directly before the ")"
    // In the full editor, typeover would move cursor past the ")".
    // At the CodeStorage level, it just inserts another ")" (typeover is in CodeView).
    codeStorage.replaceCharacters(in: NSRange(location: 5, length: 0), with: ")")
    XCTAssertEqual(codeStorage.string, "func())")
  }

  func testCurlyBracketWithNewlineAutoInsertion() throws {
    let (codeStorage, _) = makeCodeStorage()

    // Start with "if true "
    codeStorage.setAttributedString(NSAttributedString(string: "if true "))

    // Type "{" at position 8
    codeStorage.replaceCharacters(in: NSRange(location: 8, length: 0), with: "{")
    XCTAssertEqual(codeStorage.string, "if true {")

    // Type newline at position 9 - should auto-insert newline + "}"
    codeStorage.replaceCharacters(in: NSRange(location: 9, length: 0), with: "\n")
    XCTAssertEqual(codeStorage.string, "if true {\n\n}")
  }

  // MARK: - Auto-Deletion Tests

  func testRoundBracketAutoDeletion() throws {
    let (codeStorage, _) = makeCodeStorage()

    // Start with "func()" - adjacent brackets
    codeStorage.setAttributedString(NSAttributedString(string: "func()"))
    XCTAssertEqual(codeStorage.string, "func()")

    // Delete "(" at position 4 - should also delete the adjacent ")"
    codeStorage.replaceCharacters(in: NSRange(location: 4, length: 1), with: "")
    XCTAssertEqual(codeStorage.string, "func")
  }

  func testSquareBracketAutoDeletion() throws {
    let (codeStorage, _) = makeCodeStorage()

    // Start with "arr[]" - adjacent brackets
    codeStorage.setAttributedString(NSAttributedString(string: "arr[]"))
    XCTAssertEqual(codeStorage.string, "arr[]")

    // Delete "[" at position 3 - should also delete the adjacent "]"
    codeStorage.replaceCharacters(in: NSRange(location: 3, length: 1), with: "")
    XCTAssertEqual(codeStorage.string, "arr")
  }

  func testCurlyBracketAutoDeletion() throws {
    let (codeStorage, _) = makeCodeStorage()

    // Start with "if {}" - adjacent brackets
    codeStorage.setAttributedString(NSAttributedString(string: "if {}"))
    XCTAssertEqual(codeStorage.string, "if {}")

    // Delete "{" at position 3 - should also delete the adjacent "}"
    codeStorage.replaceCharacters(in: NSRange(location: 3, length: 1), with: "")
    XCTAssertEqual(codeStorage.string, "if ")
  }

  func testNoAutoDeletionWhenBracketsNotAdjacent() throws {
    let (codeStorage, _) = makeCodeStorage()

    // Start with "func(x)" - brackets with content between them
    codeStorage.setAttributedString(NSAttributedString(string: "func(x)"))
    XCTAssertEqual(codeStorage.string, "func(x)")

    // Delete "(" at position 4 - should NOT delete ")" since there's "x" between them
    codeStorage.replaceCharacters(in: NSRange(location: 4, length: 1), with: "")
    XCTAssertEqual(codeStorage.string, "funcx)")
  }

  func testAutoDeletionOnlyForOpeningBracket() throws {
    let (codeStorage, _) = makeCodeStorage()

    // Start with "func()"
    codeStorage.setAttributedString(NSAttributedString(string: "func()"))
    XCTAssertEqual(codeStorage.string, "func()")

    // Delete ")" at position 5 - should NOT trigger auto-deletion of "("
    codeStorage.replaceCharacters(in: NSRange(location: 5, length: 1), with: "")
    XCTAssertEqual(codeStorage.string, "func(")
  }

  // MARK: - Edge Cases

  func testAutoInsertionAtStartOfDocument() throws {
    let (codeStorage, _) = makeCodeStorage()

    // Start with empty
    codeStorage.setAttributedString(NSAttributedString(string: ""))

    // Type "(" at position 0 - immediately inserts ")" too
    codeStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "(")
    XCTAssertEqual(codeStorage.string, "()")

    // Type "x" at position 1 (between the brackets)
    codeStorage.replaceCharacters(in: NSRange(location: 1, length: 0), with: "x")
    XCTAssertEqual(codeStorage.string, "(x)")
  }

  func testAutoInsertionWithMultipleBracketTypes() throws {
    let (codeStorage, _) = makeCodeStorage()

    // Start with "arr"
    codeStorage.setAttributedString(NSAttributedString(string: "arr"))

    // Type "[" at position 3 - immediately inserts "]" too
    codeStorage.replaceCharacters(in: NSRange(location: 3, length: 0), with: "[")
    XCTAssertEqual(codeStorage.string, "arr[]")

    // Type "(" at position 4 (between "[" and "]") - immediately inserts "()"
    // The "]" gets pushed, resulting in properly nested: [ ( ) ]
    codeStorage.replaceCharacters(in: NSRange(location: 4, length: 0), with: "(")
    XCTAssertEqual(codeStorage.string, "arr[()]")
  }

  func testCurlyBracketWithImmediateBracketInside() throws {
    let (codeStorage, _) = makeCodeStorage()

    // Start with "if "
    codeStorage.setAttributedString(NSAttributedString(string: "if "))

    // Type "{" at position 3 - delayed, so no "}" yet
    codeStorage.replaceCharacters(in: NSRange(location: 3, length: 0), with: "{")
    XCTAssertEqual(codeStorage.string, "if {")

    // Type "(" at position 4 - this triggers both:
    // - Immediate insertion of ")" for the "("
    // - Delayed completion of "}" for the "{" (since it sees the previous "{")
    codeStorage.replaceCharacters(in: NSRange(location: 4, length: 0), with: "(")
    XCTAssertEqual(codeStorage.string, "if {()}")
  }

  static var allTests = [
    // Auto-insertion tests
    ("testRoundBracketAutoInsertion", testRoundBracketAutoInsertion),
    ("testSquareBracketAutoInsertion", testSquareBracketAutoInsertion),
    ("testCurlyBracketAutoInsertion", testCurlyBracketAutoInsertion),
    ("testNestedCommentAutoInsertion", testNestedCommentAutoInsertion),
    ("testNestedCommentAutoDeletionNotSupported", testNestedCommentAutoDeletionNotSupported),
    ("testNestedBracketAutoInsertion", testNestedBracketAutoInsertion),
    ("testNoAutoInsertionWhenTypingMatchingClose", testNoAutoInsertionWhenTypingMatchingClose),
    ("testCurlyBracketWithNewlineAutoInsertion", testCurlyBracketWithNewlineAutoInsertion),
    // Auto-deletion tests
    ("testRoundBracketAutoDeletion", testRoundBracketAutoDeletion),
    ("testSquareBracketAutoDeletion", testSquareBracketAutoDeletion),
    ("testCurlyBracketAutoDeletion", testCurlyBracketAutoDeletion),
    ("testNoAutoDeletionWhenBracketsNotAdjacent", testNoAutoDeletionWhenBracketsNotAdjacent),
    ("testAutoDeletionOnlyForOpeningBracket", testAutoDeletionOnlyForOpeningBracket),
    // Edge cases
    ("testAutoInsertionAtStartOfDocument", testAutoInsertionAtStartOfDocument),
    ("testAutoInsertionWithMultipleBracketTypes", testAutoInsertionWithMultipleBracketTypes),
    ("testCurlyBracketWithImmediateBracketInside", testCurlyBracketWithImmediateBracketInside),
  ]
}
