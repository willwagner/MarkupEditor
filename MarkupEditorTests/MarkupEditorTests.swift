//
//  MarkupEditorTests.swift
//  MarkupEditorTests
//
//  Created by Steven Harris on 3/5/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import XCTest
import MarkupEditor

struct HtmlTest {
    var description: String? = nil
    var startHtml: String
    var endHtml: String
    var startId: String
    var startOffset: Int
    var endId: String
    var endOffset: Int
    var startChildNodeIndex: Int?
    var endChildNodeIndex: Int?
    
    static func forFormatting(_ rawString: String, style: StyleContext, format: FormatContext, startingAt startOffset: Int, endingAt endOffset: Int) -> HtmlTest {
        // Return an HTMLTest appropriate for formatting a range from startOffset to endOffset in styled HTML
        // For example, to test bolding of the word "is" in the following: <p id: "p">This is a start.</p>, use:
        //      HtmlTest.forFormatting("This is a start.", style: .P, format: .B, startingAt: 5, endingAt: 7)
        // This populates the HtmlTest as follows:
        //  - startHtml : "<p id=\"p\">This is a start.</p>"
        //  - endHtml : "<p id=\"p\">This <b>is</b> a start.</p>"
        //  - startId : "p"
        //  - startOffset : 5
        //  - endId : "p"
        //  - endOffset : 7
        let lcTag = style.tag.lowercased()
        let styledWithId = rawString.styledHtml(adding: style, withId: lcTag)
        let formattedOnly = rawString.formattedHtml(adding: format, startingAt: startOffset, endingAt: endOffset)
        let styledAndFormatted = formattedOnly.styledHtml(adding: style, withId: lcTag)
        return HtmlTest(startHtml: styledWithId, endHtml: styledAndFormatted, startId: lcTag, startOffset: startOffset, endId: lcTag, endOffset: endOffset)
    }
    
    static func forUnformatting(_ rawString: String, style: StyleContext, format: FormatContext, startingAt startOffset: Int, endingAt endOffset: Int) -> HtmlTest {
        // Return an HTMLTest appropriate for unformatting a range from startOffset to endOffset in styled HTML
        // For example, to test unbolding of the word "is" in the following: <p>This <b id: "b">is</b> a start.</p>, use:
        //      HtmlTest.forUnformatting("This is a start.", style: .P, format: .B, startingAt: 5, endingAt: 7)
        // This populates the HtmlTest as follows:
        // - startHtml : "<p>This <b id=\"b\">is</b> a start.</p>"
        // - endHtml : "<p>This is a start.</p>"
        // - startId : "b"
        // - startOffset : 0
        // - endId : "b"
        // - endOffset : 2
        let lcTag = format.tag.lowercased()
        let styledOnly = rawString.styledHtml(adding: style)
        let formattedWithId = rawString.formattedHtml(adding: format, startingAt: startOffset, endingAt: endOffset, withId: lcTag)
        let styledAndFormatted = formattedWithId.styledHtml(adding: style)
        return HtmlTest(startHtml: styledAndFormatted, endHtml: styledOnly, startId: lcTag, startOffset: 0, endId: lcTag, endOffset: endOffset - startOffset)
    }
    
    func printDescription() {
        if let description = description { print(" * Test: \(description)") }
    }
    
}

class MarkupEditorTests: XCTestCase, MarkupDelegate {
    var selectionState: SelectionState = SelectionState()
    var webView: MarkupWKWebView!
    var coordinator: MarkupCoordinator!
    var loadedExpectation: XCTestExpectation = XCTestExpectation(description: "Loaded")
    var undoSetHandler: (()->Void)?
    var inputHandler: (()->Void)?
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        webView = MarkupWKWebView(markupDelegate: self)
        coordinator = MarkupCoordinator(selectionState: selectionState, markupDelegate: self, webView: webView)
        // The coordinator will receive callbacks from markup.js
        // using window.webkit.messageHandlers.test.postMessage(<message>);
        webView.configuration.userContentController.add(coordinator, name: "markup")
        wait(for: [loadedExpectation], timeout: 1)
    }
    
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        // Since we marked self as the markupDelegate, we receive the markupDidLoad message
        loadedExpectation.fulfill()
        handler?()
    }
    
    /// Execute the inputHandler once if defined, then nil it out
    func markupInput(_ view: MarkupWKWebView) {
        guard let inputHandler = inputHandler else {
            return
        }
        //print("*** handling input")
        inputHandler()
        self.inputHandler = nil
    }
    
    /// Use the inputHandlers in order, removing them as we use them
    func markupUndoSet(_ view: MarkupWKWebView) {
        guard let undoSetHandler = undoSetHandler else {
            return
        }
        //print("*** handling undoSet")
        undoSetHandler()
        self.undoSetHandler = nil
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func assertEqualStrings(expected: String, saw: String?) {
        XCTAssert(expected == saw, "Expected \(expected), saw: \(saw ?? "nil")")
    }
    
    func addInputHandler(_ handler: @escaping (()->Void)) {
        inputHandler = handler
    }
    
    func addUndoSetHandler(_ handler: @escaping (()->Void)) {
        undoSetHandler = handler
    }
    
    func testLoad() throws {
        // Do nothing other than run setupWithError
    }

    func testFormats() throws {
        // Select a range in a P styled string, apply a format to it
        for format in FormatContext.AllCases {
            let test = HtmlTest.forFormatting("This is a start.", style: .P, format: format, startingAt: 5, endingAt: 7)
            let expectation = XCTestExpectation(description: "Format \(format.tag)")
            webView.setTestHtml(value: test.startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: test.startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        XCTAssert(result)
                        let formatFollowUp = {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: test.endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                        switch format {
                        case .B:
                            self.webView.bold(handler: formatFollowUp)
                        case .I:
                            self.webView.italic(handler: formatFollowUp)
                        case .U:
                            self.webView.underline(handler: formatFollowUp)
                        case .STRIKE:
                            self.webView.strike(handler: formatFollowUp)
                        case .SUB:
                            self.webView.subscriptText(handler: formatFollowUp)
                        case .SUP:
                            self.webView.superscript(handler: formatFollowUp)
                        case .CODE:
                            self.webView.code(handler: formatFollowUp)
                        default:
                            XCTFail("Unknown format action: \(format)")
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testUndoFormats() throws {
        // Select a range in a P styled string, apply a format to it, and then undo
        for format in FormatContext.AllCases {
            let test = HtmlTest.forFormatting("This is a start.", style: .P, format: format, startingAt: 5, endingAt: 7)
            let expectation = XCTestExpectation(description: "Undo formatting of \(format.tag)")
            webView.setTestHtml(value: test.startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: test.startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        XCTAssert(result)
                        let formatFollowUp = {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: test.endHtml, saw: formatted)
                                self.webView.testUndo() {
                                    self.webView.getHtml { unformatted in
                                        self.assertEqualStrings(expected: test.startHtml, saw: unformatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                        switch format {
                        case .B:
                            self.webView.bold(handler: formatFollowUp)
                        case .I:
                            self.webView.italic(handler: formatFollowUp)
                        case .U:
                            self.webView.underline(handler: formatFollowUp)
                        case .STRIKE:
                            self.webView.strike(handler: formatFollowUp)
                        case .SUB:
                            self.webView.subscriptText(handler: formatFollowUp)
                        case .SUP:
                            self.webView.superscript(handler: formatFollowUp)
                        case .CODE:
                            self.webView.code(handler: formatFollowUp)
                        default:
                            XCTFail("Unknown format action: \(format)")
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testUnformats() throws {
        // Given a range of formatted text, toggle the format off
        for format in FormatContext.AllCases {
            let test = HtmlTest.forUnformatting("This is a start.", style: .P, format: format, startingAt: 5, endingAt: 7)
            let expectation = XCTestExpectation(description: "Format \(format.tag)")
            webView.setTestHtml(value: test.startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: test.startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        XCTAssert(result)
                        let formatFollowUp = {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: test.endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                        switch format {
                        case .B:
                            self.webView.bold(handler: formatFollowUp)
                        case .I:
                            self.webView.italic(handler: formatFollowUp)
                        case .U:
                            self.webView.underline(handler: formatFollowUp)
                        case .STRIKE:
                            self.webView.strike(handler: formatFollowUp)
                        case .SUB:
                            self.webView.subscriptText(handler: formatFollowUp)
                        case .SUP:
                            self.webView.superscript(handler: formatFollowUp)
                        case .CODE:
                            self.webView.code(handler: formatFollowUp)
                        default:
                            XCTFail("Unknown format action: \(format)")
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testUndoUnformats() throws {
        // Given a range of formatted text, toggle the format off, then undo
        for format in FormatContext.AllCases {
            let rawString = "This is a start."
            let test = HtmlTest.forUnformatting(rawString, style: .P, format: format, startingAt: 5, endingAt: 7)
            // The undo doesn't preserve the id that is injected by .forUnformatting, so construct startHTML
            // below for comparison post-undo.
            let formattedString = rawString.formattedHtml(adding: format, startingAt: 5, endingAt: 7, withId: nil)
            let startHtml = formattedString.styledHtml(adding: .P)
            let expectation = XCTestExpectation(description: "Format \(format.tag)")
            webView.setTestHtml(value: test.startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: test.startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        XCTAssert(result)
                        let formatFollowUp = {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: test.endHtml, saw: formatted)
                                self.webView.testUndo() {
                                    self.webView.getHtml { unformatted in
                                        self.assertEqualStrings(expected: startHtml, saw: unformatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                        switch format {
                        case .B:
                            self.webView.bold(handler: formatFollowUp)
                        case .I:
                            self.webView.italic(handler: formatFollowUp)
                        case .U:
                            self.webView.underline(handler: formatFollowUp)
                        case .STRIKE:
                            self.webView.strike(handler: formatFollowUp)
                        case .SUB:
                            self.webView.subscriptText(handler: formatFollowUp)
                        case .SUP:
                            self.webView.superscript(handler: formatFollowUp)
                        case .CODE:
                            self.webView.code(handler: formatFollowUp)
                        default:
                            XCTFail("Unknown format action: \(format)")
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testFormatSelections() throws {
        // Select a caret location in a formatted string and make sure getSelection identifies the format properly
        // This is important for the toolbar indication of formatting as the cursor selection changes
        for format in FormatContext.AllCases {
            let rawString = "This is a start."
            let formattedString = rawString.formattedHtml(adding: format, startingAt: 5, endingAt: 7, withId: format.tag)
            let startHtml = formattedString.styledHtml(adding: .P)
            let expectation = XCTestExpectation(description: "Select inside of format \(format.tag)")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: format.tag, startOffset: 1, endId: format.tag, endOffset: 1) { result in
                        XCTAssert(result)
                        switch format {
                        case .B:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.bold)
                                expectation.fulfill()
                            }
                        case .I:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.italic)
                                expectation.fulfill()
                            }
                        case .U:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.underline)
                                expectation.fulfill()
                            }
                        case .STRIKE:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.strike)
                                expectation.fulfill()
                            }
                        case .SUB:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.sub)
                                expectation.fulfill()
                            }
                        case .SUP:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.sup)
                                expectation.fulfill()
                            }
                        case .CODE:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.code)
                                expectation.fulfill()
                            }
                        default:
                            XCTFail("Unknown format action: \(format)")
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testStyles() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Replace p with h1",
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<h1><b id=\"b\"><i id=\"i\">Hello </i>world</b></h1>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(in: state, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Replace h2 with h6",
                    startHtml: "<h2 id=\"h2\">Hello world</h2>",
                    endHtml: "<h6>Hello world</h6>",
                    startId: "h2",
                    startOffset: 0,
                    endId: "h2",
                    endOffset: 10
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(in: state, with: .H6) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Replace h3 with p",
                    startHtml: "<h3 id=\"h3\">Hello world</h3>",
                    endHtml: "<p>Hello world</p>",
                    startId: "h3",
                    startOffset: 2,
                    endId: "h3",
                    endOffset: 8
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(in: state, with: .P) {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Setting and replacing styles")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }

    func testUndoStyles() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Replace p with h1",
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(in: state, with: .H1) {
                            self.webView.testUndo() {
                                handler()
                            }
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Replace h2 with h6",
                    startHtml: "<h2 id=\"h2\">Hello world</h2>",
                    endHtml: "<h2>Hello world</h2>",
                    startId: "h2",
                    startOffset: 0,
                    endId: "h2",
                    endOffset: 10
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(in: state, with: .H6) {
                            self.webView.testUndo() {
                                handler()
                            }
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Replace h3 with p",
                    startHtml: "<h3 id=\"h3\">Hello world</h3>",
                    endHtml: "<h3>Hello world</h3>",
                    startId: "h3",
                    startOffset: 2,
                    endId: "h3",
                    endOffset: 8
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(in: state, with: .P) {
                            self.webView.testUndo() {
                                handler()
                            }
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Undoing the setting and replacing of styles")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    

    func testMultiElementSelections() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "\"He|llo \" is italic and bold, \"world\" is bold; unformat italic",
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<p><b id=\"b\">Hello world</b></p>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "\"He|llo \" is italic and bold, \"world\" is bold; unformat bold",
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<p><i id=\"i\">Hello </i>world</p>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "\"world\" is italic, select \"|Hello <i>world</i>|\" and format bold",
                    startHtml: "<p id=\"p\">Hello <i id=\"i\">world</i></p>",
                    endHtml: "<p id=\"p\"><b>Hello <i id=\"i\">world</i></b></p>",
                    startId: "p",
                    startOffset: 0,
                    endId: "i",
                    endOffset: 5
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "\"Hello \" is italic and bold, \"wo|rld\" is bold; unformat bold",
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<p><i id=\"i\">Hello </i>world</p>",
                    startId: "b",
                    startOffset: 2,
                    endId: "b",
                    endOffset: 2
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "\"He|llo \" is italic and bold, \"world\" is bold; unformat bold",
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<p><i id=\"i\">Hello </i>world</p>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
        ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Unformatting nested tags")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testBlockQuotes() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Increase quote level, selection in text element",
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<blockquote><p id=\"p\">Hello <b id=\"b\">world</b></p></blockquote>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Increase quote level, selection in a non-text element",
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Decrease quote level from 1 to 0, selection in a non-text element, no styling",
                    startHtml: "<blockquote><b id=\"b\"><i id=\"i\">Hello </i>world</b></blockquote>",
                    endHtml: "<b id=\"b\"><i id=\"i\">Hello </i>world</b>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Decrease quote level from 1 to 0, selection in a non-text element, with styling",
                    startHtml: "<blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote>",
                    endHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Decrease quote level from 2 to 1, selection in a non-text element",
                    startHtml: "<blockquote><blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote></blockquote>",
                    endHtml: "<blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Increase quote level in an embedded paragraph in a blockquote, selection in a non-text element",
                    startHtml:  "<blockquote><p><b id=\"b1\"><i id=\"i1\">Hello </i>world</b></p><p><b id=\"b2\"><i id=\"i2\">Hello </i>world</b></p></blockquote>",
                    endHtml:    "<blockquote><p><b id=\"b1\"><i id=\"i1\">Hello </i>world</b></p><blockquote><p><b id=\"b2\"><i id=\"i2\">Hello </i>world</b></p></blockquote></blockquote>",
                    startId: "i2",
                    startOffset: 2,
                    endId: "i2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Increasing and decreasing block levels")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testUndoBlockQuotes() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Increase quote level, selection in text element",
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<blockquote><p id=\"p\">Hello <b id=\"b\">world</b></p></blockquote>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Increase quote level, selection in a non-text element",
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Decrease quote level from 1 to 0, selection in a non-text element, no styling",
                    startHtml: "<blockquote><b id=\"b\"><i id=\"i\">Hello </i>world</b></blockquote>",
                    endHtml: "<b id=\"b\"><i id=\"i\">Hello </i>world</b>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Decrease quote level from 1 to 0, selection in a non-text element, with styling",
                    startHtml: "<blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote>",
                    endHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Decrease quote level from 2 to 1, selection in a non-text element",
                    startHtml: "<blockquote><blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote></blockquote>",
                    endHtml: "<blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Increase quote level in an embedded paragraph in a blockquote, selection in a non-text element",
                    startHtml:  "<blockquote><p><b id=\"b1\"><i id=\"i1\">Hello </i>world</b></p><p><b id=\"b2\"><i id=\"i2\">Hello </i>world</b></p></blockquote>",
                    endHtml:    "<blockquote><p><b id=\"b1\"><i id=\"i1\">Hello </i>world</b></p><blockquote><p><b id=\"b2\"><i id=\"i2\">Hello </i>world</b></p></blockquote></blockquote>",
                    startId: "i2",
                    startOffset: 2,
                    endId: "i2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Increasing and decreasing block levels")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                self.webView.testUndo() {
                                    self.webView.getHtml { unformatted in
                                        self.assertEqualStrings(expected: startHtml, saw: unformatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testLists() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Make a paragraph into an ordered list",
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<ol><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ol>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Make a paragraph into an unordered list",
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<ul><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ul>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Remove a list item from a single-element unordered list, thereby removing the list, too",
                    startHtml: "<ul><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ul>",
                    endHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Remove a list item from a single-element ordered list, thereby removing the list, too",
                    startHtml: "<ol><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ol>",
                    endHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Remove a list item from a multi-element unordered list, leaving the list in place",
                    startHtml: "<ul><li><p>Hello <b id=\"b\">world1</b></p></li><li><p>Hello <b>world2</b></p></li></ul>",
                    endHtml: "<ul><p>Hello <b id=\"b\">world1</b></p><li><p>Hello <b>world2</b></p></li></ul>",
                    startId: "b",
                    startOffset: 2,
                    endId: "b",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Change one of the list items in a multi-element unordered list to an ordered list item",
                    startHtml: "<ul><li><p>Hello <b id=\"b\">world1</b></p></li><li><p>Hello <b>world2</b></p></li></ul>",
                    endHtml: "<ol><li><p>Hello <b id=\"b\">world1</b></p></li></ol><ul><li><p>Hello <b>world2</b></p></li></ul>",
                    startId: "b",
                    startOffset: 2,
                    endId: "b",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Mucking about with lists and selections in them")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testUndoLists() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Make a paragraph into an ordered list",
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<ol><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ol>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Make a paragraph into an unordered list",
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<ul><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ul>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Remove a list item from a single-element unordered list, thereby removing the list, too",
                    startHtml: "<ul><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ul>",
                    endHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Remove a list item from a single-element ordered list, thereby removing the list, too",
                    startHtml: "<ol><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ol>",
                    endHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Remove a list item from a multi-element unordered list, leaving the list in place",
                    startHtml: "<ul><li><p>Hello <b id=\"b\">world1</b></p></li><li><p>Hello <b>world2</b></p></li></ul>",
                    endHtml: "<ul><p>Hello <b id=\"b\">world1</b></p><li><p>Hello <b>world2</b></p></li></ul>",
                    startId: "b",
                    startOffset: 2,
                    endId: "b",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Change one of the list items in a multi-element unordered list to an ordered list item",
                    startHtml: "<ul><li><p>Hello <b id=\"b\">world1</b></p></li><li><p>Hello <b>world2</b></p></li></ul>",
                    endHtml: "<ol><li><p>Hello <b id=\"b\">world1</b></p></li></ol><ul><li><p>Hello <b>world2</b></p></li></ul>",
                    startId: "b",
                    startOffset: 2,
                    endId: "b",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Mucking about with lists and selections in them")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                self.webView.testUndo() {
                                    self.webView.getHtml { unformatted in
                                        self.assertEqualStrings(expected: startHtml, saw: unformatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testListEnterCollapsed() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        //
        // The startHtml includes styled items in the <ul> and unstyled items in the <ol>, and we test both.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Enter at end of h5",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5></li><li><h5><br></h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h5",
                    startOffset: 3,
                    endId: "h5",
                    endOffset: 3,
                    startChildNodeIndex: 2,
                    endChildNodeIndex: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter at beginning of h5",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5><br></h5></li><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h5",
                    startOffset: 0,
                    endId: "h5",
                    endOffset: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter in \"Bul|leted item 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bul</h5></li><li><h5>leted&nbsp;<i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h5",
                    startOffset: 3,
                    endId: "h5",
                    endOffset: 3
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter in \"Bulleted item 1|.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i>&nbsp;1</h5></li><li><h5>.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h5",
                    startOffset: 2,
                    endId: "h5",
                    endOffset: 2,
                    startChildNodeIndex: 2,
                    endChildNodeIndex: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter in italicized \"item\" in \"Bulleted it|em 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">it</i></h5></li><li><h5><i>em</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter at end of unstyled \"Numbered item 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li><p><br></p></li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",
                    startOffset: 16,
                    endId: "ol1",
                    endOffset: 16
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter at beginning of unstyled \"Numbered item 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li><p><br></p></li><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",
                    startOffset: 0,
                    endId: "ol1",
                    endOffset: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Split unstyled \"Number|ed item 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Number</li><li><p>ed item 1.</p></li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",
                    startOffset: 6,
                    endId: "ol1",
                    endOffset: 6
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Enter being pressed in a list with various collapsed selections")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        // Execute the action to press Enter at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testUndoListEnterCollapsed() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        //
        // The startHtml includes styled items in the <ul> and unstyled items in the <ol>, and we test both.
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Enter in \"Bul|leted item 1.\"",
                startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bul</h5></li><li><h5>leted&nbsp;<i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                startId: "h5",
                startOffset: 3,
                endId: "h5",
                endOffset: 3
            ),
            HtmlTest(
                description: "Enter at end of h5",
                startHtml: "<p>Hello</p><ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                endHtml: "<p>Hello</p><ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5></li><li><h5><br></h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                startId: "h5",
                startOffset: 3,
                endId: "h5",
                endOffset: 3,
                startChildNodeIndex: 2,
                endChildNodeIndex: 2
            ),
            HtmlTest(
                description: "Enter at beginning of h5",
                startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                endHtml: "<ul><li><h5><br></h5></li><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                startId: "h5",
                startOffset: 0,
                endId: "h5",
                endOffset: 0
            ),
            HtmlTest(
                description: "Enter in \"Bulleted item 1|.\"",
                startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i>&nbsp;1</h5></li><li><h5>.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                startId: "h5",
                startOffset: 2,
                endId: "h5",
                endOffset: 2,
                startChildNodeIndex: 2,
                endChildNodeIndex: 2
            ),
            HtmlTest(
                description: "Enter in italicized \"item\" in \"Bulleted it|em 1.\"",
                startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">it</i></h5></li><li><h5><i>em</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                startId: "i",
                startOffset: 2,
                endId: "i",
                endOffset: 2
            ),
            HtmlTest(
                description: "Enter at end of unstyled \"Numbered item 1.\"",
                startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li><p><br></p></li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                startId: "ol1",
                startOffset: 16,
                endId: "ol1",
                endOffset: 16
            ),
            HtmlTest(
                description: "Enter at beginning of unstyled \"Numbered item 1.\"",
                startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li><p><br></p></li><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                startId: "ol1",
                startOffset: 0,
                endId: "ol1",
                endOffset: 0
            ),
            HtmlTest(
                description: "Split unstyled \"Number|ed item 1.\"",
                startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Number</li><li><p>ed item 1.</p></li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                startId: "ol1",
                startOffset: 6,
                endId: "ol1",
                endOffset: 6
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Undo enter being pressed in a list with various collapsed selections")
            // We set a handler for when 'undoSet' is received, which happens after the undo stack is all set after _doListEnter.
            // Within that handler, we set a handler for when 'input' is received, which happens after the undo is complete.
            // When the undo is done, the html should be what we started with.
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        // Define the handler to execute after undoSet is received (i.e., once the undoData has
                        // been pushed to the stack and can be executed).
                        self.addUndoSetHandler {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                // Define the handler after input is received (i.e., once the undo is complete)
                                self.addInputHandler {
                                    self.webView.getHtml { unformatted in
                                        self.assertEqualStrings(expected: startHtml, saw: unformatted)
                                        expectation.fulfill()
                                    }
                                }
                                // Kick off the undo operation in the list we did enter in
                                self.webView.testUndoListEnter()
                            }
                        }
                        // Kick off the enter operation in the list we selected
                        self.webView.testListEnter()
                    }
                }
            }
            wait(for: [expectation], timeout: 3)
        }
    }

    func testListEnterRange() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        //
        // The startHtml includes styled items in the <ul> and unstyled items in the <ol>, and we test both.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Word in single styled list item",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P&nbsp;</p></li><li><p>item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",     // Select "Numbered "
                    startOffset: 2,
                    endId: "ol1",
                    endOffset: 11,
                    startChildNodeIndex: 0,
                    endChildNodeIndex: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Word in single unstyled list item",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered&nbsp;</li><li><p>6.</p></li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol6",     // Select "item "
                    startOffset: 9,
                    endId: "ol6",
                    endOffset: 14
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Part of a formatted item in a styled list item",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">i</i></h5></li><li><h5><i>m</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "i",     // Select "<i id=\"i\">i|te|m</i>" which is itself inside of an <h5>
                    startOffset: 1,
                    endId: "i",
                    endOffset: 3
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "The entire formatted item in a styled list item (note the zero width chars in the result)",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">\u{200B}</i></h5></li><li><h5><i>\u{200B}</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "i",     // Select the entire "<i id=\"i\">item</i>" which is itself inside of an <h5>
                    startOffset: 0,
                    endId: "i",
                    endOffset: 4
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection in one styled list item, end in another",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P&nbsp;</p></li><li><p>Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",     // Select "P |Numbered item 1."
                    startOffset: 2,
                    endId: "ol3",       // Select "P |Numbered item 3."
                    endOffset: 2,
                    startChildNodeIndex: 0,
                    endChildNodeIndex: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection at start of one unstyled list item, end in another",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li><p><br></p></li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol6",     // Select "|Numbered item 6."
                    startOffset: 0,
                    endId: "ol8",       // Select "|Numbered item 8."
                    endOffset: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection at start of one styled list item, end in another",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li><p><br></p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol2",     // Select "|P Numbered item 2."
                    startOffset: 0,
                    endId: "ol4",       // Select "|P Numbered item 4."
                    endOffset: 0,
                    startChildNodeIndex: 0,
                    endChildNodeIndex: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection in a styled list item, end in an unstyled one",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Num</p></li><li><p>bered item 7.</p></li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol2",     // Select "P Num|bered item 2."
                    startOffset: 5,
                    endId: "ol7",       // Select "Num|bered item 7."
                    endOffset: 3,
                    startChildNodeIndex: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection in a bulleted list item, end in an ordered unformatted one",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bul</h5></li><li><h5>bered item 7.</h5><ol><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h5",     // Select "Bul|leted item 2."
                    startOffset: 3,
                    endId: "ol7",       // Select "Num|bered item 7."
                    endOffset: 3
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection in a bulleted list item, end in an ordered formatted one",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bul</h5></li><li><h5>bered item 3.</h5><ol><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h51",     // Select "Bul|leted item 2."
                    startOffset: 3,
                    endId: "ol3",       // Select "P Num|bered item 3."
                    endOffset: 5,
                    endChildNodeIndex: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            /*
            (
                HtmlTest(
                    description: "Enter in \"Bulleted item 1|.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i>&nbsp;1</h5></li><li><h5>.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h5",
                    startOffset: 2,
                    endId: "h5",
                    endOffset: 2,
                    startChildNodeIndex: 2,
                    endChildNodeIndex: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter in italicized \"item\" in \"Bulleted it|em 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">it</i></h5></li><li><h5><i>em</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter at end of unstyled \"Numbered item 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li><p><br></p></li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",
                    startOffset: 16,
                    endId: "ol1",
                    endOffset: 16
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter at beginning of unstyled \"Numbered item 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li><p><br></p></li><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",
                    startOffset: 0,
                    endId: "ol1",
                    endOffset: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Split unstyled \"Number|ed item 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Number</li><li><p>ed item 1.</p></li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",
                    startOffset: 6,
                    endId: "ol1",
                    endOffset: 6
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
             */
        ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: test.description ?? "Enter being pressed in a list with various range selections")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        // Execute the action to press Enter at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testUndoListEnterRange() {
        let htmlTests: [HtmlTest] = [
                HtmlTest(
                    description: "Word in single styled list item",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P&nbsp;</p></li><li><p>item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",     // Select "Numbered "
                    startOffset: 2,
                    endId: "ol1",
                    endOffset: 11,
                    startChildNodeIndex: 0,
                    endChildNodeIndex: 0
                ),
                HtmlTest(
                    description: "Word in single unstyled list item",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered&nbsp;</li><li><p>6.</p></li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol6",     // Select "item "
                    startOffset: 9,
                    endId: "ol6",
                    endOffset: 14
                ),
                HtmlTest(
                    description: "Part of a formatted item in a styled list item",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">i</i></h5></li><li><h5><i>m</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "i",     // Select "<i id=\"i\">i|te|m</i>" which is itself inside of an <h5>
                    startOffset: 1,
                    endId: "i",
                    endOffset: 3
                ),
                HtmlTest(
                    description: "The entire formatted item in a styled list item (note the zero width chars in the result)",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">\u{200B}</i></h5></li><li><h5><i>\u{200B}</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "i",     // Select the entire "<i id=\"i\">item</i>" which is itself inside of an <h5>
                    startOffset: 0,
                    endId: "i",
                    endOffset: 4
                ),
                HtmlTest(
                    description: "Begin selection in one styled list item, end in another",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P&nbsp;</p></li><li><p>Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",     // Select "P |Numbered item 1."
                    startOffset: 2,
                    endId: "ol3",       // Select "P |Numbered item 3."
                    endOffset: 2,
                    startChildNodeIndex: 0,
                    endChildNodeIndex: 0
                ),
                HtmlTest(
                    description: "Begin selection at start of one unstyled list item, end in another",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li><p><br></p></li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol6",     // Select "|Numbered item 6."
                    startOffset: 0,
                    endId: "ol8",       // Select "|Numbered item 8."
                    endOffset: 0
                ),
                HtmlTest(
                    description: "Begin selection at start of one styled list item, end in another",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li><p><br></p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol2",     // Select "|P Numbered item 2."
                    startOffset: 0,
                    endId: "ol4",       // Select "|P Numbered item 4."
                    endOffset: 0,
                    startChildNodeIndex: 0,
                    endChildNodeIndex: 0
                ),
                HtmlTest(
                    description: "Begin selection in a styled list item, end in an unstyled one",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Num</p></li><li><p>bered item 7.</p></li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol2",     // Select "P Num|bered item 2."
                    startOffset: 5,
                    endId: "ol7",       // Select "Num|bered item 7."
                    endOffset: 3,
                    startChildNodeIndex: 0
                ),
                HtmlTest(
                    description: "Begin selection in a bulleted list item, end in an ordered unformatted one",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bul</h5></li><li><h5>bered item 7.</h5><ol><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h5",     // Select "Bul|leted item 1."
                    startOffset: 3,
                    endId: "ol7",       // Select "Num|bered item 7."
                    endOffset: 3
                ),
                HtmlTest(
                    description: "Begin selection in a bulleted list item, end in an ordered formatted one",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bul</h5></li><li><h5>bered item 3.</h5><ol><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h51",     // Select "Bul|leted item 1."
                    startOffset: 3,
                    endId: "ol3",       // Select "P Num|bered item 3."
                    endOffset: 5,
                    endChildNodeIndex: 0
                ),
            /*
            (
                HtmlTest(
                    description: "Enter in \"Bulleted item 1|.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i>&nbsp;1</h5></li><li><h5>.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h5",
                    startOffset: 2,
                    endId: "h5",
                    endOffset: 2,
                    startChildNodeIndex: 2,
                    endChildNodeIndex: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter in italicized \"item\" in \"Bulleted it|em 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">it</i></h5></li><li><h5><i>em</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter at end of unstyled \"Numbered item 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li><p><br></p></li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",
                    startOffset: 16,
                    endId: "ol1",
                    endOffset: 16
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter at beginning of unstyled \"Numbered item 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li><p><br></p></li><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",
                    startOffset: 0,
                    endId: "ol1",
                    endOffset: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Split unstyled \"Number|ed item 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Number</li><li><p>ed item 1.</p></li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",
                    startOffset: 6,
                    endId: "ol1",
                    endOffset: 6
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
             */
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Undo enter being pressed in a list with various collapsed selections")
            // We set a handler for when 'undoSet' is received, which happens after the undo stack is all set after _doListEnter.
            // Within that handler, we set a handler for when 'input' is received, which happens after the undo is complete.
            // When the undo is done, the html should be what we started with.
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        // Define the handler to execute after undoSet is received (i.e., once the undoData has
                        // been pushed to the stack and can be executed).
                        self.addUndoSetHandler {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                // Define the handler after input is received (i.e., once the undo is complete)
                                self.addInputHandler {
                                    self.webView.getHtml { unformatted in
                                        self.assertEqualStrings(expected: startHtml, saw: unformatted)
                                        expectation.fulfill()
                                    }
                                }
                                // Kick off the undo operation in the list we did enter in
                                self.webView.testUndoListEnter()
                            }
                        }
                        // Kick off the enter operation in the list we selected
                        self.webView.testListEnter()
                    }
                }
            }
            wait(for: [expectation], timeout: 3)
        }
    }
    
    func testInsertEmpty() throws {
        /*
         From this oldie but goodie... https://bugs.webkit.org/show_bug.cgi?id=15256
         
         For example, given an HTML block like this:

             <div contentEditable="true"><div id="scratchpad"></div></div>

         and code like this:

             document.getElementById("scratchpad").innerHTML = "<div id=\"foo\">blah</div><div id=\"bar\">blah</div>";

             var sel = window.getSelection();
             sel.removeAllRanges();
             var range = document.createRange();

             range.setStartAfter(document.getElementById("foo"));
             range.setEndAfter(document.getElementById("foo"));
             sel.addRange(range);

             document.execCommand("insertHTML", false, "<div id=\"baz\">-</div>");

         One would expect this snippet to result in:

             <div id="foo">blah</div><div id="baz">-</div><div id="bar">blah</div>

         but instead, you get:

             <div id="foo">blah</div><div id="bar">-blah</div>

         I've tried every combination of set{Start|End}{After|Before|} that I can think of, and even things like setBaseAndExtent, modifying the selection object directly by extending it in either direction, etc.  Nothing works.
         Comment 38
         */
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Make a paragraph into an ordered list",
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<ol><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ol>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            )
        ]
        for (test, action) in htmlTestAndActions {
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Mucking about with lists and selections in them")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testUndoInsertEmpty() throws {
        /* See the notes in testInsertEmpty */
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Make a paragraph into an ordered list",
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<ol><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ol>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            )
        ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Mucking about with lists and selections in them")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                self.webView.testUndo() {
                                    self.webView.getHtml { unformatted in
                                        self.assertEqualStrings(expected: startHtml, saw: unformatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }

}
