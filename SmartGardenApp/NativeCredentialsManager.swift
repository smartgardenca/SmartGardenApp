//
//  NativeCredentialsManager.swift
//  SmartGardenApp
//
//  Created by Xu Han on 2025/4/17.
//

import Foundation
import WebKit

class NativeCredentialsManager: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?

    init(webView: WKWebView?) {
        self.webView = webView
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "NativeCredentialsManager" else { return }

        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else {
            return
        }
        
        switch action {
        case "getLastLoggedInUsername":
            if let callbackId = body["callbackId"] as? String {
                        let username = UserDefaults.standard.string(forKey: "lastLoggedInUsername") ?? "null"
                        evaluateJS("window.NativeCredentialsManager._resolveResult('\(escapeJS(callbackId))', '\(escapeJS(username))')")
                        print(username)
                    }
        case "saveLastLoggedInUsername":
            if let username = body["username"] as? String {
                UserDefaults.standard.set(username, forKey: "lastLoggedInUsername")
            }

        case "saveCredentials":
            if let username = body["username"] as? String,
               let encrypted = body["encryptedPasswordBase64"] as? String {
                UserDefaults.standard.set(encrypted, forKey: "credentials_\(username)")
            }

        case "getEncryptedPassword":
            if let callbackId = body["callbackId"] as? String {
                if let username = body["username"] as? String {
                    let encrypted = UserDefaults.standard.string(forKey: "credentials_\(username)") ?? "null"
                    evaluateJS("window.NativeCredentialsManager._resolveResult('\(escapeJS(callbackId))', '\(escapeJS(encrypted))')")
                    print(encrypted)
                }
            }

        case "decryptPassword":
            if let encrypted = body["encryptedPasswordBase64"] as? String {
                let decrypted = fakeDecrypt(encrypted)
                evaluateJS("window.NativeCredentialsManager._resolveResult('\(escapeJS(decrypted))')")
            }

        case "clearCredentials":
            if let username = body["username"] as? String {
                UserDefaults.standard.removeObject(forKey: "credentials_\(username)")
            }

        default:
            break
        }
    }

    private func evaluateJS(_ js: String) {
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    private func fakeDecrypt(_ input: String) -> String {
        return "[Decrypted]" + input
    }

    private func escapeJS(_ str: String) -> String {
        return str.replacingOccurrences(of: "\\", with: "\\\\")
                  .replacingOccurrences(of: "'", with: "\\'")
                  .replacingOccurrences(of: "\n", with: "\\n")
    }
}
