//
//  MarkupWKWebView+Extensions.swift
//  MarkupEditor
//
//  Created by Steven Harris on 12/28/23.
//

import MarkupEditor
import OSLog

extension MarkupWKWebView {
    
    public func addDiv(_ div: MarkupDiv, handler: (()->Void)? = nil) {
        let id = div.id
        let parentId = div.parentId
        let cssClass = div.cssClass
        let attributes = div.attributes
        var jsonAttributes: String?
        if !attributes.isEmpty, let jsonData = try? JSONSerialization.data(withJSONObject: attributes.options) {
            jsonAttributes = String(data: jsonData, encoding: .utf8)
        }
        let htmlContents = div.htmlContents.escaped
        evaluateJavaScript("MU.addDiv('\(id)', '\(parentId)', '\(cssClass)', '\(jsonAttributes ?? "null")', '\(htmlContents)')") { result, error in
            if let error {
                Logger.webview.error("Error: \(error)")
            }
            handler?()
        }
    }
    
    public func addButtonGroup(_ buttonGroup: MarkupButtonGroup, handler: (()->Void)? = nil) {
        let id = buttonGroup.id
        let cssClass = buttonGroup.cssClass
        let divId = buttonGroup.divId
        evaluateJavaScript("MU.addDiv('\(id)', '\(divId)', '\(cssClass)')") { result, error in
            if let error {
                Logger.webview.error("Error: \(error)")
            }
            handler?()
        }
    }

    public func addButton(_ button: MarkupButton, in divId: String, handler: (()->Void)? = nil) {
        let id = button.id
        let cssClass = button.cssClass
        let label = button.label
        let callbackName = button.callbackName
        evaluateJavaScript("MU.addButton('\(id)', '\(cssClass)', '\(label)', '\(divId)', '\(callbackName)')") { result, error in
            if let error {
                Logger.webview.error("Error: \(error)")
            }
            handler?()
        }
    }

}

