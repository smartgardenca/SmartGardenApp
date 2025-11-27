import SwiftUI
import WebKit

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()

        // Camera JavaScript injection (as before)
        let cameraJs = """
            window.NativeCamera = {
                openCamera: function(callbackName) {
                    window.webkit.messageHandlers.NativeCamera.postMessage({ method: 'openCamera', callback: callbackName });
                }
            };
            """
        controller.addUserScript(
            WKUserScript(
                source: cameraJs,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )

        // Credentials JavaScript injection (as before)
        let credentialsJs = """
            window.NativeCredentialsManager = {
                getLastLoggedInUsername: function () {
                    return new Promise(function (resolve, reject) {
                        const callbackId = "cb_" + Date.now() + "_" + Math.random().toString(36).substring(2);

                        window.NativeCredentialsManager._callbacks = window.NativeCredentialsManager._callbacks || {};
                        window.NativeCredentialsManager._callbacks[callbackId] = resolve;

                        window.webkit.messageHandlers.NativeCredentialsManager.postMessage({
                            action: "getLastLoggedInUsername",
                            callbackId: callbackId
                        });
                    });
                },
                _resolveResult: function (callbackId, result) {
                    if (window.NativeCredentialsManager._callbacks && typeof window.NativeCredentialsManager._callbacks[callbackId] === "function") {
                        window.NativeCredentialsManager._callbacks[callbackId](result);
                        delete window.NativeCredentialsManager._callbacks[callbackId];
                    }
                },
                saveLastLoggedInUsername: function (username) {
                    window.webkit.messageHandlers.NativeCredentialsManager.postMessage({
                        action: "saveLastLoggedInUsername",
                        username: username
                    });
                },
                saveCredentials: function (username, encryptedPasswordBase64) {
                    window.webkit.messageHandlers.NativeCredentialsManager.postMessage({
                        action: "saveCredentials",
                        username: username,
                        encryptedPasswordBase64: encryptedPasswordBase64
                    });
                },
                getEncryptedPassword: function (username) {
                    return new Promise(function (resolve, reject) {
                        const callbackId = "cb_" + Date.now() + "_" + Math.random().toString(36).substring(2);

                        window.NativeCredentialsManager._callbacks = window.NativeCredentialsManager._callbacks || {};
                        window.NativeCredentialsManager._callbacks[callbackId] = resolve;

                        window.webkit.messageHandlers.NativeCredentialsManager.postMessage({
                            action: "getEncryptedPassword",
                            username: username,
                            callbackId: callbackId
                        });
                    });
                },
                decryptPassword: function (encryptedPasswordBase64) {
                    return new Promise(function (resolve, reject) {
                        const callbackId = "cb_" + Date.now() + "_" + Math.random().toString(36).substring(2);

                        window.NativeCredentialsManager._callbacks = window.NativeCredentialsManager._callbacks || {};
                        window.NativeCredentialsManager._callbacks[callbackId] = resolve;

                        window.webkit.messageHandlers.NativeCredentialsManager.postMessage({
                            action: "decryptPassword",
                            encryptedPasswordBase64: encryptedPasswordBase64,
                            callbackId: callbackId
                        });
                    });
                },
                clearCredentials: function (username) {
                    window.webkit.messageHandlers.NativeCredentialsManager.postMessage({
                        action: "clearCredentials",
                        username: username
                    });
                }
            };
            """
        controller.addUserScript(
            WKUserScript(
                source: credentialsJs,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )

        // Log interception JavaScript
        let logScript = """
            (function() {
                const originalLog = console.log;
                console.log = function(message) {
                    window.webkit.messageHandlers.loggingHandler.postMessage(message);
                    originalLog.apply(console, arguments);
                };
            })();
            """
        controller.addUserScript(
            WKUserScript(
                source: logScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )

        let config = WKWebViewConfiguration()
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        if let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController
        {
            let camera = NativeCamera(webView: webView, viewController: rootVC)
            controller.add(camera, name: "NativeCamera")

            let credentialsManager = NativeCredentialsManager(webView: webView)
            controller.add(credentialsManager, name: "NativeCredentialsManager")
        }

        // Set the coordinator as the message handler
        webView.configuration.userContentController.add(context.coordinator, name: "loggingHandler")

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "loggingHandler", let logMessage = message.body as? String {
                print("Web Console Log: \(logMessage)")
                // Here you can process the logMessage as needed in your SwiftUI code
            }
        }
    }
}
