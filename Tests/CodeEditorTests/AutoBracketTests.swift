//
//  AutoBracketTests.swift
//
//
//  Tests for auto-bracket insertion and deletion functionality.
//

import XCTest
import RegexBuilder
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

  /// Creates a CodeStorage with a custom LanguageConfiguration.
  private func makeCodeStorage(with config: LanguageConfiguration) -> (CodeStorage, CodeStorageDelegate) {
    let codeStorageDelegate = CodeStorageDelegate(with: config, setText: { _ in })
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

  // MARK: - Configuration Tests

  func testNoAutoInsertionWhenRoundBracketsDisabled() throws {
    // Create a config with supportsRoundBrackets: false
    let config = LanguageConfiguration(
      name: "NoParens",
      supportsSquareBrackets: true,
      supportsCurlyBrackets: true,
      supportsRoundBrackets: false,
      stringRegex: nil,
      characterRegex: nil,
      numberRegex: nil,
      singleLineComment: "//",
      nestedComment: nil,
      identifierRegex: nil,
      operatorRegex: nil,
      reservedIdentifiers: [],
      reservedOperators: []
    )
    let (codeStorage, _) = makeCodeStorage(with: config)

    // Start with "func"
    codeStorage.setAttributedString(NSAttributedString(string: "func"))
    XCTAssertEqual(codeStorage.string, "func")

    // Type "(" at position 4 - should NOT auto-insert ")" since round brackets are disabled
    codeStorage.replaceCharacters(in: NSRange(location: 4, length: 0), with: "(")
    XCTAssertEqual(codeStorage.string, "func(")
  }

  func testNoAutoInsertionWhenSquareBracketsDisabled() throws {
    // Create a config with supportsSquareBrackets: false
    let config = LanguageConfiguration(
      name: "NoSquare",
      supportsSquareBrackets: false,
      supportsCurlyBrackets: true,
      supportsRoundBrackets: true,
      stringRegex: nil,
      characterRegex: nil,
      numberRegex: nil,
      singleLineComment: "//",
      nestedComment: nil,
      identifierRegex: nil,
      operatorRegex: nil,
      reservedIdentifiers: [],
      reservedOperators: []
    )
    let (codeStorage, _) = makeCodeStorage(with: config)

    // Start with "arr"
    codeStorage.setAttributedString(NSAttributedString(string: "arr"))
    XCTAssertEqual(codeStorage.string, "arr")

    // Type "[" at position 3 - should NOT auto-insert "]" since square brackets are disabled
    codeStorage.replaceCharacters(in: NSRange(location: 3, length: 0), with: "[")
    XCTAssertEqual(codeStorage.string, "arr[")
  }

  func testNoAutoInsertionWhenCurlyBracketsDisabled() throws {
    // Create a config with supportsCurlyBrackets: false
    let config = LanguageConfiguration(
      name: "NoCurly",
      supportsSquareBrackets: true,
      supportsCurlyBrackets: false,
      supportsRoundBrackets: true,
      stringRegex: nil,
      characterRegex: nil,
      numberRegex: nil,
      singleLineComment: "//",
      nestedComment: nil,
      identifierRegex: nil,
      operatorRegex: nil,
      reservedIdentifiers: [],
      reservedOperators: []
    )
    let (codeStorage, _) = makeCodeStorage(with: config)

    // Start with "if "
    codeStorage.setAttributedString(NSAttributedString(string: "if "))
    XCTAssertEqual(codeStorage.string, "if ")

    // Type "{" at position 3 - should NOT recognize as bracket
    codeStorage.replaceCharacters(in: NSRange(location: 3, length: 0), with: "{")
    XCTAssertEqual(codeStorage.string, "if {")

    // Type " " at position 4 - should NOT auto-insert "}" since curly brackets are disabled
    codeStorage.replaceCharacters(in: NSRange(location: 4, length: 0), with: " ")
    XCTAssertEqual(codeStorage.string, "if { ")
  }

  func testNoAutoInsertionWithNoneConfiguration() throws {
    // LanguageConfiguration.none has all brackets disabled
    let (codeStorage, _) = makeCodeStorage(with: .none)

    // Start empty
    codeStorage.setAttributedString(NSAttributedString(string: ""))

    // Type "(" - should NOT auto-insert
    codeStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "(")
    XCTAssertEqual(codeStorage.string, "(")

    // Type "[" - should NOT auto-insert
    codeStorage.replaceCharacters(in: NSRange(location: 1, length: 0), with: "[")
    XCTAssertEqual(codeStorage.string, "([")

    // Type "{" then " " - should NOT auto-insert
    codeStorage.replaceCharacters(in: NSRange(location: 2, length: 0), with: "{")
    XCTAssertEqual(codeStorage.string, "([{")
    codeStorage.replaceCharacters(in: NSRange(location: 3, length: 0), with: " ")
    XCTAssertEqual(codeStorage.string, "([{ ")
  }

  func testCurlyBracketAutoInsertionWithNoCommentConfig() throws {
    // Test a config similar to Markdown: brackets enabled but no comments
    // This ensures curly bracket auto-insertion works without singleLineComment
    let config = LanguageConfiguration(
      name: "MarkdownLike",
      supportsSquareBrackets: true,
      supportsCurlyBrackets: true,
      supportsRoundBrackets: true,
      stringRegex: nil,
      characterRegex: nil,
      numberRegex: nil,
      singleLineComment: nil,  // No single line comment (like markdown)
      nestedComment: nil,
      identifierRegex: nil,
      operatorRegex: nil,
      reservedIdentifiers: [],
      reservedOperators: []
    )
    let (codeStorage, _) = makeCodeStorage(with: config)

    // Start with "if "
    codeStorage.setAttributedString(NSAttributedString(string: "if "))
    XCTAssertEqual(codeStorage.string, "if ")

    // Type "{" at position 3 - delayed, so no "}" yet
    codeStorage.replaceCharacters(in: NSRange(location: 3, length: 0), with: "{")
    XCTAssertEqual(codeStorage.string, "if {")

    // Type " " at position 4 - should trigger auto-insertion of "}"
    codeStorage.replaceCharacters(in: NSRange(location: 4, length: 0), with: " ")
    XCTAssertEqual(codeStorage.string, "if { }")
  }

  func testCurlyBracketAutoInsertionWithNewlineNoCommentConfig() throws {
    // Test curly bracket with newline in a no-comment config
    let config = LanguageConfiguration(
      name: "MarkdownLike",
      supportsSquareBrackets: true,
      supportsCurlyBrackets: true,
      supportsRoundBrackets: true,
      stringRegex: nil,
      characterRegex: nil,
      numberRegex: nil,
      singleLineComment: nil,
      nestedComment: nil,
      identifierRegex: nil,
      operatorRegex: nil,
      reservedIdentifiers: [],
      reservedOperators: []
    )
    let (codeStorage, _) = makeCodeStorage(with: config)

    // Start with "if "
    codeStorage.setAttributedString(NSAttributedString(string: "if "))

    // Type "{" at position 3
    codeStorage.replaceCharacters(in: NSRange(location: 3, length: 0), with: "{")
    XCTAssertEqual(codeStorage.string, "if {")

    // Type newline at position 4 - should auto-insert newline + "}"
    codeStorage.replaceCharacters(in: NSRange(location: 4, length: 0), with: "\n")
    XCTAssertEqual(codeStorage.string, "if {\n\n}")
  }

  func testCurlyBracketAutoInsertionWithStringRegexConfig() throws {
    // Test with stringRegex set (like markdown's inline code `...`)
    let inlineCodeRegex: Regex<Substring> = Regex {
      "`"
      OneOrMore {
        CharacterClass(.anyOf("`\n").inverted)
      }
      "`"
    }
    let config = LanguageConfiguration(
      name: "MarkdownLikeWithCode",
      supportsSquareBrackets: true,
      supportsCurlyBrackets: true,
      supportsRoundBrackets: true,
      stringRegex: inlineCodeRegex,
      characterRegex: nil,
      numberRegex: nil,
      singleLineComment: nil,
      nestedComment: nil,
      identifierRegex: nil,
      operatorRegex: nil,
      reservedIdentifiers: [],
      reservedOperators: ["##", "**", "~~"]
    )
    let (codeStorage, _) = makeCodeStorage(with: config)

    // Start with "if "
    codeStorage.setAttributedString(NSAttributedString(string: "if "))
    XCTAssertEqual(codeStorage.string, "if ")

    // Type "{" at position 3 - delayed
    codeStorage.replaceCharacters(in: NSRange(location: 3, length: 0), with: "{")
    XCTAssertEqual(codeStorage.string, "if {")

    // Type " " at position 4 - should trigger auto-insertion of "}"
    codeStorage.replaceCharacters(in: NSRange(location: 4, length: 0), with: " ")
    XCTAssertEqual(codeStorage.string, "if { }")
  }

  func testCurlyBracketAutoInsertionWithStringRegexNewlineConfig() throws {
    // Test with stringRegex and newline
    let inlineCodeRegex: Regex<Substring> = Regex {
      "`"
      OneOrMore {
        CharacterClass(.anyOf("`\n").inverted)
      }
      "`"
    }
    let config = LanguageConfiguration(
      name: "MarkdownLikeWithCode",
      supportsSquareBrackets: true,
      supportsCurlyBrackets: true,
      supportsRoundBrackets: true,
      stringRegex: inlineCodeRegex,
      characterRegex: nil,
      numberRegex: nil,
      singleLineComment: nil,
      nestedComment: nil,
      identifierRegex: nil,
      operatorRegex: nil,
      reservedIdentifiers: [],
      reservedOperators: ["##", "**", "~~"]
    )
    let (codeStorage, _) = makeCodeStorage(with: config)

    // Start with "if "
    codeStorage.setAttributedString(NSAttributedString(string: "if "))

    // Type "{" at position 3
    codeStorage.replaceCharacters(in: NSRange(location: 3, length: 0), with: "{")
    XCTAssertEqual(codeStorage.string, "if {")

    // Type newline at position 4 - should auto-insert newline + "}"
    codeStorage.replaceCharacters(in: NSRange(location: 4, length: 0), with: "\n")
    XCTAssertEqual(codeStorage.string, "if {\n\n}")
  }

  func testCurlyBracketAutoInsertionWithAutoIndentation() throws {
    // Test curly bracket completion when auto-indentation adds multiple characters
    // This simulates pressing Enter after `{` when the system adds newline + indentation
    let (codeStorage, _) = makeCodeStorage()

    // Start with "if "
    codeStorage.setAttributedString(NSAttributedString(string: "if "))
    XCTAssertEqual(codeStorage.string, "if ")

    // Type "{" at position 3 - delayed
    codeStorage.replaceCharacters(in: NSRange(location: 3, length: 0), with: "{")
    XCTAssertEqual(codeStorage.string, "if {")

    // Simulate auto-indentation: insert newline + 2 spaces (3 characters total)
    // This is what happens when pressing Enter and the system adds indentation
    codeStorage.replaceCharacters(in: NSRange(location: 4, length: 0), with: "\n  ")
    // Should auto-insert "\n}" after the indentation (no extra indent since opening line has none)
    XCTAssertEqual(codeStorage.string, "if {\n  \n}")
  }

  func testCurlyBracketAutoInsertionWithNestedIndentation() throws {
    // Test that closing bracket matches indentation of the line with opening bracket
    let (codeStorage, _) = makeCodeStorage()

    // Start with indented code: "  if "
    codeStorage.setAttributedString(NSAttributedString(string: "  if "))
    XCTAssertEqual(codeStorage.string, "  if ")

    // Type "{" at position 5 - delayed
    codeStorage.replaceCharacters(in: NSRange(location: 5, length: 0), with: "{")
    XCTAssertEqual(codeStorage.string, "  if {")

    // Simulate auto-indentation: insert newline + 4 spaces (inner indentation)
    codeStorage.replaceCharacters(in: NSRange(location: 6, length: 0), with: "\n    ")
    // Should auto-insert "\n  }" - matching the 2-space indent of the opening line
    XCTAssertEqual(codeStorage.string, "  if {\n    \n  }")
  }

  func testCurlyBracketAutoInsertionExactMarkdownConfig() throws {
    // Exact replication of MathTex's markdown configuration
    let inlineMathRegex: Regex<Substring> = Regex {
      "$"
      NegativeLookahead { "$" }
      OneOrMore(.reluctant) {
        CharacterClass(.anyOf("$\n").inverted)
      }
      "$"
      NegativeLookahead { "$" }
    }
    let inlineCodeRegex: Regex<Substring> = Regex {
      "`"
      NegativeLookahead { "`" }
      OneOrMore(.reluctant) {
        CharacterClass(.anyOf("`\n").inverted)
      }
      "`"
    }
    let markdownOperators = ["$$$", "$$", "######", "#####", "####", "###", "##", "#",
                             "***", "**", "*", "___", "__", "_", "---", ">", "~~", "```"]

    let config = LanguageConfiguration(
      name: "Markdown",
      supportsSquareBrackets: true,
      supportsCurlyBrackets: true,
      supportsRoundBrackets: true,
      stringRegex: inlineMathRegex,
      characterRegex: inlineCodeRegex,
      numberRegex: nil,
      singleLineComment: nil,
      nestedComment: nil,
      identifierRegex: nil,
      operatorRegex: nil,
      reservedIdentifiers: [],
      reservedOperators: markdownOperators
    )
    let (codeStorage, _) = makeCodeStorage(with: config)

    // Start with empty
    codeStorage.setAttributedString(NSAttributedString(string: ""))
    XCTAssertEqual(codeStorage.string, "")

    // Type "{" at position 0 - delayed
    codeStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "{")
    XCTAssertEqual(codeStorage.string, "{")

    // Type newline at position 1 - should trigger auto-insertion of newline + "}"
    codeStorage.replaceCharacters(in: NSRange(location: 1, length: 0), with: "\n")
    XCTAssertEqual(codeStorage.string, "{\n\n}")
  }

  // MARK: - Typeover Tests

  func testTypeoverForRoundBracket() throws {
    let (codeStorage, delegate) = makeCodeStorage()

    // Set up text with cursor before closing bracket: "func(|)"
    codeStorage.setAttributedString(NSAttributedString(string: "func()"))

    // Should typeover when typing ")" at position 5 (before existing ")")
    let result = delegate.shouldTypeover(for: codeStorage, at: 5, inserting: ")")
    XCTAssertEqual(result, 1, "Should return 1 to skip the closing bracket")
  }

  func testTypeoverForSquareBracket() throws {
    let (codeStorage, delegate) = makeCodeStorage()

    // Set up text: "arr[0|]"
    codeStorage.setAttributedString(NSAttributedString(string: "arr[0]"))

    // Should typeover when typing "]" at position 5 (before existing "]")
    let result = delegate.shouldTypeover(for: codeStorage, at: 5, inserting: "]")
    XCTAssertEqual(result, 1, "Should return 1 to skip the closing bracket")
  }

  func testTypeoverForCurlyBracket() throws {
    let (codeStorage, delegate) = makeCodeStorage()

    // Set up text: "if {|}"
    codeStorage.setAttributedString(NSAttributedString(string: "if {}"))

    // Should typeover when typing "}" at position 4 (before existing "}")
    let result = delegate.shouldTypeover(for: codeStorage, at: 4, inserting: "}")
    XCTAssertEqual(result, 1, "Should return 1 to skip the closing bracket")
  }

  func testNoTypeoverWhenCharacterDoesNotMatch() throws {
    let (codeStorage, delegate) = makeCodeStorage()

    // Set up text: "func(|x)"
    codeStorage.setAttributedString(NSAttributedString(string: "func(x)"))

    // Should NOT typeover when typing ")" at position 5 (before "x", not ")")
    let result = delegate.shouldTypeover(for: codeStorage, at: 5, inserting: ")")
    XCTAssertNil(result, "Should return nil when character doesn't match")
  }

  func testNoTypeoverAtEndOfDocument() throws {
    let (codeStorage, delegate) = makeCodeStorage()

    // Set up text: "func("
    codeStorage.setAttributedString(NSAttributedString(string: "func("))

    // Should NOT typeover when at end of document
    let result = delegate.shouldTypeover(for: codeStorage, at: 5, inserting: ")")
    XCTAssertNil(result, "Should return nil when at end of document")
  }

  func testNoTypeoverForOpeningBracket() throws {
    let (codeStorage, delegate) = makeCodeStorage()

    // Set up text: "(()"
    codeStorage.setAttributedString(NSAttributedString(string: "(()"))

    // Should NOT typeover for opening brackets
    let result = delegate.shouldTypeover(for: codeStorage, at: 0, inserting: "(")
    XCTAssertNil(result, "Should return nil for opening brackets")
  }

  func testNoTypeoverForMultipleCharacters() throws {
    let (codeStorage, delegate) = makeCodeStorage()

    // Set up text: "func()"
    codeStorage.setAttributedString(NSAttributedString(string: "func()"))

    // Should NOT typeover when inserting multiple characters
    let result = delegate.shouldTypeover(for: codeStorage, at: 5, inserting: "))")
    XCTAssertNil(result, "Should return nil for multi-character insertions")
  }

  func testNoTypeoverWhenBracketsDisabled() throws {
    // Create config with round brackets disabled
    let config = LanguageConfiguration(
      name: "NoParens",
      supportsSquareBrackets: true,
      supportsCurlyBrackets: true,
      supportsRoundBrackets: false,
      stringRegex: nil,
      characterRegex: nil,
      numberRegex: nil,
      singleLineComment: "//",
      nestedComment: nil,
      identifierRegex: nil,
      operatorRegex: nil,
      reservedIdentifiers: [],
      reservedOperators: []
    )
    let (codeStorage, delegate) = makeCodeStorage(with: config)

    // Set up text: "func()"
    codeStorage.setAttributedString(NSAttributedString(string: "func()"))

    // Should NOT typeover ")" when round brackets are disabled
    let result = delegate.shouldTypeover(for: codeStorage, at: 5, inserting: ")")
    XCTAssertNil(result, "Should return nil when round brackets are disabled")

    // But should still typeover "]" since square brackets are enabled
    codeStorage.setAttributedString(NSAttributedString(string: "arr[]"))
    let squareResult = delegate.shouldTypeover(for: codeStorage, at: 4, inserting: "]")
    XCTAssertEqual(squareResult, 1, "Should typeover for enabled bracket types")
  }

  // MARK: - Custom Typeover Handler Tests

  func testCustomTypeoverHandler() throws {
    let (codeStorage, delegate) = makeCodeStorage()

    // Set up a custom handler for markdown asterisk
    delegate.typeoverHandler = { typed, location, text in
      guard typed == "*", location < text.count else { return nil }
      let index = text.index(text.startIndex, offsetBy: location)
      return text[index] == "*" ? 1 : nil
    }

    // Set up text: "**bold**" with cursor before the second *
    codeStorage.setAttributedString(NSAttributedString(string: "**bold**"))

    // Should typeover when typing "*" at position 7 (before last "*")
    let result = delegate.shouldTypeover(for: codeStorage, at: 7, inserting: "*")
    XCTAssertEqual(result, 1, "Custom handler should return 1 for asterisk typeover")
  }

  func testCustomTypeoverHandlerTakesPrecedence() throws {
    let (codeStorage, delegate) = makeCodeStorage()

    // Set up a custom handler that blocks ALL typeover
    delegate.typeoverHandler = { typed, location, text in
      // Return nil for everything - this prevents default bracket typeover
      return nil
    }

    // Set up text: "func()"
    codeStorage.setAttributedString(NSAttributedString(string: "func()"))

    // Should still typeover ")" because handler returns nil (falls through to built-in)
    let result = delegate.shouldTypeover(for: codeStorage, at: 5, inserting: ")")
    XCTAssertEqual(result, 1, "Built-in should handle when custom handler returns nil")
  }

  func testCustomTypeoverHandlerCanOverrideBuiltIn() throws {
    let (codeStorage, delegate) = makeCodeStorage()

    // Set up a custom handler that returns 0 to block typeover
    // (returning 0 means "skip 0 characters" which effectively does nothing useful,
    // but since it's non-nil, it takes precedence over built-in)
    var handlerCalled = false
    delegate.typeoverHandler = { typed, location, text in
      if typed == ")" {
        handlerCalled = true
        return 2  // Custom behavior: skip 2 characters instead of 1
      }
      return nil
    }

    // Set up text: "func())"
    codeStorage.setAttributedString(NSAttributedString(string: "func())"))

    // Custom handler should take precedence and return 2
    let result = delegate.shouldTypeover(for: codeStorage, at: 5, inserting: ")")
    XCTAssertTrue(handlerCalled, "Custom handler should be called")
    XCTAssertEqual(result, 2, "Custom handler should override built-in with custom skip count")
  }

  func testCustomTypeoverHandlerForNonBracketCharacters() throws {
    let (codeStorage, delegate) = makeCodeStorage()

    // Set up a handler for backtick (not a built-in bracket)
    delegate.typeoverHandler = { typed, location, text in
      guard typed == "`", location < text.count else { return nil }
      let index = text.index(text.startIndex, offsetBy: location)
      return text[index] == "`" ? 1 : nil
    }

    // Set up text: "`code`"
    codeStorage.setAttributedString(NSAttributedString(string: "`code`"))

    // Should typeover when typing "`" at position 5 (before last "`")
    let result = delegate.shouldTypeover(for: codeStorage, at: 5, inserting: "`")
    XCTAssertEqual(result, 1, "Custom handler should work for non-bracket characters")

    // Should NOT typeover when the character doesn't match
    let noMatch = delegate.shouldTypeover(for: codeStorage, at: 1, inserting: "`")
    XCTAssertNil(noMatch, "Should return nil when character doesn't match")
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
    // Configuration tests
    ("testNoAutoInsertionWhenRoundBracketsDisabled", testNoAutoInsertionWhenRoundBracketsDisabled),
    ("testNoAutoInsertionWhenSquareBracketsDisabled", testNoAutoInsertionWhenSquareBracketsDisabled),
    ("testNoAutoInsertionWhenCurlyBracketsDisabled", testNoAutoInsertionWhenCurlyBracketsDisabled),
    ("testNoAutoInsertionWithNoneConfiguration", testNoAutoInsertionWithNoneConfiguration),
    // Typeover tests
    ("testTypeoverForRoundBracket", testTypeoverForRoundBracket),
    ("testTypeoverForSquareBracket", testTypeoverForSquareBracket),
    ("testTypeoverForCurlyBracket", testTypeoverForCurlyBracket),
    ("testNoTypeoverWhenCharacterDoesNotMatch", testNoTypeoverWhenCharacterDoesNotMatch),
    ("testNoTypeoverAtEndOfDocument", testNoTypeoverAtEndOfDocument),
    ("testNoTypeoverForOpeningBracket", testNoTypeoverForOpeningBracket),
    ("testNoTypeoverForMultipleCharacters", testNoTypeoverForMultipleCharacters),
    ("testNoTypeoverWhenBracketsDisabled", testNoTypeoverWhenBracketsDisabled),
    // Custom typeover handler tests
    ("testCustomTypeoverHandler", testCustomTypeoverHandler),
    ("testCustomTypeoverHandlerTakesPrecedence", testCustomTypeoverHandlerTakesPrecedence),
    ("testCustomTypeoverHandlerCanOverrideBuiltIn", testCustomTypeoverHandlerCanOverrideBuiltIn),
    ("testCustomTypeoverHandlerForNonBracketCharacters", testCustomTypeoverHandlerForNonBracketCharacters),
  ]
}
