import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    func makeUIView(context: Context) -> WKWebView {
        let userController = WKUserContentController()

        // =======================
        // JS API 注入：Camera
        // =======================
        let cameraJs = """
        window.NativeCamera = {
            openCamera: function(callbackName) {
                window.webkit.messageHandlers.NativeCamera.postMessage({ method: 'openCamera', callback: callbackName });
            }
        };
        """
        userController.addUserScript(WKUserScript(source: cameraJs,
                                                  injectionTime: .atDocumentStart,
                                                  forMainFrameOnly: true))

        // =======================
        // JS API 注入：Credentials
        // =======================
        let credentialsJs = """
        window.NativeCredentialsManager = {
            _callbacks: {},
            getLastLoggedInUsername: function() {
                return new Promise(function(resolve) {
                    const callbackId = "cb_" + Date.now() + "_" + Math.random().toString(36).substring(2);
                    window.NativeCredentialsManager._callbacks[callbackId] = resolve;
                    window.webkit.messageHandlers.NativeCredentialsManager.postMessage({
                        action: "getLastLoggedInUsername",
                        callbackId: callbackId
                    });
                });
            },
            getEncryptedPassword: function(username) {
                return new Promise(function(resolve) {
                    const callbackId = "cb_" + Date.now() + "_" + Math.random().toString(36).substring(2);
                    window.NativeCredentialsManager._callbacks[callbackId] = resolve;
                    window.webkit.messageHandlers.NativeCredentialsManager.postMessage({
                        action: "getEncryptedPassword",
                        username: username,
                        callbackId: callbackId
                    });
                });
            },
            decryptPassword: function(encryptedPasswordBase64) {
                return new Promise(function(resolve) {
                    const callbackId = "cb_" + Date.now() + "_" + Math.random().toString(36).substring(2);
                    window.NativeCredentialsManager._callbacks[callbackId] = resolve;
                    window.webkit.messageHandlers.NativeCredentialsManager.postMessage({
                        action: "decryptPassword",
                        encryptedPasswordBase64: encryptedPasswordBase64,
                        callbackId: callbackId
                    });
                });
            },
            saveLastLoggedInUsername: function(username) {
                window.webkit.messageHandlers.NativeCredentialsManager.postMessage({
                    action: "saveLastLoggedInUsername",
                    username: username
                });
            },
            saveCredentials: function(username, encryptedPasswordBase64) {
                window.webkit.messageHandlers.NativeCredentialsManager.postMessage({
                    action: "saveCredentials",
                    username: username,
                    encryptedPasswordBase64: encryptedPasswordBase64
                });
            },
            clearCredentials: function(username) {
                window.webkit.messageHandlers.NativeCredentialsManager.postMessage({
                    action: "clearCredentials",
                    username: username
                });
            },
            _resolveResult: function(callbackId, result) {
                if (window.NativeCredentialsManager._callbacks[callbackId]) {
                    window.NativeCredentialsManager._callbacks[callbackId](result);
                    delete window.NativeCredentialsManager._callbacks[callbackId];
                }
            }
        };
        """
        userController.addUserScript(WKUserScript(source: credentialsJs,
                                                  injectionTime: .atDocumentStart,
                                                  forMainFrameOnly: false))

        // =======================
        // JS Log 拦截
        // =======================
        let logJs = """
        (function() {
            const originalLog = console.log;
            console.log = function() {
                window.webkit.messageHandlers.loggingHandler.postMessage(Array.from(arguments).join(" "));
                originalLog.apply(console, arguments);
            };
        })();
        """
        userController.addUserScript(WKUserScript(source: logJs,
                                                  injectionTime: .atDocumentStart,
                                                  forMainFrameOnly: false))

        // =======================
        // 创建 WebView
        // =======================
        let config = WKWebViewConfiguration()
        config.userContentController = userController

        let webView = WKWebView(frame: .zero, configuration: config)
        
        // 关闭系统自动 safe-area 调整
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        // 避免滚动视图自动加 inset
        webView.scrollView.contentInset = .zero
        webView.scrollView.scrollIndicatorInsets = .zero
        
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        
        // 启动网络监听
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                // 当网络状态变为可用时，回到主线程刷新
                DispatchQueue.main.async {
                    if webView.url == nil || webView.title == nil || webView.title?.isEmpty == true {
                        print("检测到网络权限已授予，正在自动刷新...")
                        webView.load(URLRequest(url: url))
                    }
                }
            }
        }
        monitor.start(queue: monitorQueue)

        // =======================
        // 注册 Native Handler
        // =======================
        if let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController
        {
            // Camera
            let camera = NativeCamera(webView: webView, viewController: rootVC)
            userController.add(camera, name: "NativeCamera")

            // Credentials
            let credentialsManager = NativeCredentialsManager(webView: webView)
            userController.add(credentialsManager, name: "NativeCredentialsManager")
        }

        // Logging
        webView.configuration.userContentController.add(context.coordinator, name: "loggingHandler")

        // 设置 Coordinator 为 navigationDelegate
        webView.navigationDelegate = context.coordinator as WKNavigationDelegate

        // 加载页面
        let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 20)
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // =======================
    // Coordinator
    // =======================
    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        // Logging
        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            if message.name == "loggingHandler", let logMessage = message.body as? String {
                print("Web Console Log:", logMessage)
            }
        }

        // Native Ready 注入
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("""
                window.NativeIOSReady = true;
                window.dispatchEvent(new Event('native-ready'));
            """) { _, error in
                if let error = error {
                    print("Failed to inject native-ready:", error)
                } else {
                    print(" Native Ready injected")
                }
            }
        }
        
        // 1. 处理初始化加载时的错误（如域名解析失败、断网）
            func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
                handleLoadingError(webView: webView, error: error)
            }

            // 2. 处理加载过程中的错误
            func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
                handleLoadingError(webView: webView, error: error)
            }

            private func handleLoadingError(webView: WKWebView, error: Error) {
                // 如果是取消加载（比如快速切换页面），则不处理
                let nsError = error as NSError
                if nsError.code == NSURLErrorCancelled { return }

                let errorHtml = """
                <!DOCTYPE html>
                <html>
                <head>
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <style>
                        body { font-family: -apple-system; text-align: center; padding: 50px; color: #333; }
                        .icon { font-size: 48px; margin-bottom: 20px; }
                        .title { font-size: 20px; font-weight: bold; }
                        .msg { color: #666; margin: 10px 0 30px; }
                        button { 
                            background: #007AFF; color: white; border: none; 
                            padding: 10px 25px; border-radius: 8px; font-size: 16px; 
                        }
                    </style>
                </head>
                <body>
                    <div class="icon">📡</div>
                    <div class="title">网络连接失败</div>
                    <div class="msg">请检查你的网络设置后重试</div>
                    <button onclick="location.reload()">重新加载</button>
                </body>
                </html>
                """
                webView.loadHTMLString(errorHtml, baseURL: nil)
            }
    }
}
