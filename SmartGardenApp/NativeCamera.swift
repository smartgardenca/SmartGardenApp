
import Foundation
import WebKit
import UIKit

class NativeCamera: NSObject, WKScriptMessageHandler, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    weak var webView: WKWebView?
    weak var viewController: UIViewController?
    
    init(webView: WKWebView, viewController: UIViewController?) {
        self.webView = webView
        self.viewController = viewController
        super.init()
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print("NativeCamera called by JS")
        guard message.name == "NativeCamera",
              let body = message.body as? [String: Any],
              let method = body["method"] as? String else {
            print("Can't parse the JS")
            return
        }
        if method == "openCamera" {
            let callback = body["callback"] as? String
            openCamera(callbackName: callback)
        }
    }
    
    private func openCamera(callbackName: String?) {
        print("enter openCamera...")
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            print("Camera not available")
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        
        DispatchQueue.main.async {
            self.viewController?.present(picker, animated: true, completion: nil)
        }
        
        self.pendingCallbackName = callbackName
    }
    
    private var pendingCallbackName: String?
    
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        if let image = info[.originalImage] as? UIImage,
           let imageData = image.jpegData(compressionQuality: 0.8) {
            let base64 = imageData.base64EncodedString()
            
            if let callback = pendingCallbackName {
                let js = "window.\(callback)(\"data:image/jpeg;base64,\(base64)\", null);"
                webView?.evaluateJavaScript(js, completionHandler: { (result, error) in
                    if let error = error {
                        print("Failure：\(error)")
                    }
                })
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
        if let callback = pendingCallbackName {
            let js = "window.\(callback)(null, \"User cancelled\");"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
