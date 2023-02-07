import Foundation
import Capacitor
import GCDWebServer

@available(iOS 11.0, *)
class WebviewOverlay: UIViewController, WKUIDelegate, WKNavigationDelegate {
    var id: String?
    var webview: WKWebView?
    var plugin: WebviewOverlayPlugin!
    var configuration: WKWebViewConfiguration!

    var closeFullscreenButton: UIButton!
    var topSafeArea: CGFloat!

    var webServer: GCDWebServer?

    var currentDecisionHandler: ((WKNavigationResponsePolicy) -> Void)? = nil

    var openNewWindow: Bool = false

    var currentUrl: URL?

    var loadUrlCall: CAPPluginCall?

    init(_ plugin: WebviewOverlayPlugin, configuration: WKWebViewConfiguration, id: String) {
        super.init(nibName: "WebviewOverlay", bundle: nil)
        self.plugin = plugin
        self.configuration = configuration
        self.id = id
    }

    deinit {
        self.clearDecisionHandler()
        self.webview?.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        self.webview = WKWebView(frame: .zero, configuration: self.configuration)
        self.webview?.uiDelegate = self
        self.webview?.navigationDelegate = self

        view = self.webview
        view.isHidden = plugin.hidden
        self.webview?.scrollView.bounces = false
        self.webview?.allowsBackForwardNavigationGestures = true

        // self.webview?.isOpaque = false

        let button = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 60, y: 20, width: 40, height: 40))
        let image = UIImage(named: "icon", in: Bundle(for: NSClassFromString("WebviewOverlayPlugin")!), compatibleWith: nil)
        button.setImage(image, for: .normal)
        button.isHidden = true;
        button.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        button.adjustsImageWhenHighlighted = false
        button.layer.cornerRadius = 0.5 * button.bounds.size.width
        // button.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.regular))
        blur.frame = button.bounds
        blur.layer.cornerRadius = 0.5 * button.bounds.size.width
        blur.clipsToBounds = true
        blur.isUserInteractionEnabled = false
        button.insertSubview(blur, at: 0)
        button.bringSubviewToFront(button.imageView!)

        self.closeFullscreenButton = button
        view.addSubview(self.closeFullscreenButton)

        self.webview?.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
    }

    override func viewDidLayoutSubviews() {
        self.topSafeArea = view.safeAreaInsets.top
        self.closeFullscreenButton.frame = CGRect(x: UIScreen.main.bounds.width - 60, y: self.topSafeArea + 20, width: 40, height: 40)
    }

    // @objc func buttonAction(sender: UIButton!) {
    //     plugin.toggleFullscreen()
    // }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        currentUrl = webView.url
        view.isHidden = plugin.hidden
        if (plugin.hidden) {
            self.notify("updateSnapshot", data: [:])
        }
        if (self.loadUrlCall != nil) {
            self.loadUrlCall?.resolve()
            self.loadUrlCall = nil
        }
        self.notify("pageLoaded", data: [:])

        // Remove tap highlight
        let script = "function addStyleString(str) {" +
            "var node = document.createElement('style');" +
            "node.innerHTML = str;" +
            "document.body.appendChild(node);" +
            "}" +
        "addStyleString('html, body {-webkit-tap-highlight-color: transparent;}');"
        webView.evaluateJavaScript(script)
    }

    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            if (plugin.hasListeners("navigationHandler")) {
                self.openNewWindow = true
            }
            self.loadUrl(url)
        }
        return nil
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.clearDecisionHandler()
    }

    func clearDecisionHandler() {
        if (self.currentDecisionHandler != nil) {
            self.currentDecisionHandler!(.allow)
            self.currentDecisionHandler = nil
        }
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if (self.currentDecisionHandler != nil) {
            self.clearDecisionHandler()
        }

        let event_name = "navigationHandler_\(self.id!)"
        if (plugin.hasListeners(event_name)) {
            self.currentDecisionHandler = decisionHandler
            self.notify(event_name, data: [
                "url": navigationResponse.response.url?.absoluteString ?? "",
                "newWindow": self.openNewWindow,
                "sameHost": currentUrl?.host == navigationResponse.response.url?.host
            ])
            self.openNewWindow = false
        }
        else {
            decisionHandler(.allow)
            return
        }
    }

    public func clearWebServer() {
        if (self.webServer != nil) {
            if (self.webServer?.isRunning == true) {
                self.webServer?.stop()
            }
            self.webServer = nil
        }
    }

    public func loadUrl(_ url: URL) {
        if url.absoluteString.hasPrefix("file") {
            self.clearWebServer()
            self.webServer = GCDWebServer()
            self.webServer?.addGETHandler(forBasePath: "/", directoryPath: url.deletingLastPathComponent().path, indexFilename: nil, cacheAge: 3600, allowRangeRequests: true)
            do {
                try self.webServer?.start(options: [
                    GCDWebServerOption_BindToLocalhost: true
                ])
            } catch {
                print(error)
            }
            self.webview?.load(URLRequest(url: (self.webServer?.serverURL?.appendingPathComponent(url.lastPathComponent))!))
        }
        else {
            self.webview?.load(URLRequest(url: url))
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (keyPath == "estimatedProgress") {
            self.notify("progress", data: ["value":self.webview?.estimatedProgress ?? 1])
        }
    }

    public func notify(_ eventName: String, data: [String : Any]?) {
        // Add ID to event data
        var idData = data ?? [:]
        idData["id"] = self.id
        
        // Propagate event
        self.plugin.notifyListeners(eventName, data: idData)
    }
}

@available(iOS 11.0, *)
@objc(WebviewOverlayPlugin)
public class WebviewOverlayPlugin: CAPPlugin {

    var width: CGFloat!
    var height: CGFloat!
    var x: CGFloat!
    var y: CGFloat!

    var hidden: Bool = false

    var fullscreen: Bool = false

    var overlays: [String: WebviewOverlay] = [:]

    /**
     * Capacitor Plugin load
     */
    override public func load() {}

    @objc func open(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            // Generate an ID to refer to this browser context as
            let browser_uuid = NSUUID().uuidString

            let webConfiguration = WKWebViewConfiguration()
            webConfiguration.allowsInlineMediaPlayback = true
            webConfiguration.mediaTypesRequiringUserActionForPlayback = []
            webConfiguration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

            // Content controller
            let javascript = call.getString("javascript") ?? ""
            if (javascript != "") {
                var injectionTime: WKUserScriptInjectionTime!

                switch(call.getInt("injectionTime")) {
                    case 0:
                        injectionTime = .atDocumentStart
                        break;
                    case 1:
                        injectionTime = .atDocumentEnd
                        break;
                    default:
                        injectionTime = .atDocumentStart
                        break;
                }

                let contentController = WKUserContentController()
                let script = WKUserScript(source: String(javascript), injectionTime: injectionTime, forMainFrameOnly: true)
                contentController.addUserScript(script)
                webConfiguration.userContentController = contentController
            }

            // Create the overlay
            let overlay = WebviewOverlay(self, configuration: webConfiguration, id: browser_uuid)

            // Save it to the dictionary
            self.overlays[browser_uuid] = overlay

            guard let urlString = call.getString("url") else {
                call.reject("Must provide a URL to open")
                return
            }

            let url = URL(string: urlString)

            self.hidden = false

            self.width = CGFloat(call.getFloat("width") ?? 0)
            self.height = CGFloat(call.getFloat("height") ?? 0)
            self.x = CGFloat(call.getFloat("x") ?? 0)
            self.y = CGFloat(call.getFloat("y") ?? 0)

            overlay.view.isHidden = false
            self.bridge?.viewController?.addChild(overlay)
            self.bridge?.viewController?.view.addSubview(overlay.view)
            overlay.view.frame = CGRect(x: self.x, y: self.y, width: self.width, height: self.height)
            overlay.didMove(toParent: self.bridge?.viewController)

            overlay.loadUrl(url!)

            // Send the ID back to the caller
            call.resolve([
                "id": browser_uuid
            ])
        }
    }

    @objc func close(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let browser_uuid = call.getString("id") else {
                call.reject("Must provide a browser id")
                return
            }

            guard let overlay = self.overlays[browser_uuid] else {
                call.reject("Can't find browser matching id")
                return
            }

            overlay.view.removeFromSuperview()
            overlay.removeFromParent()
            overlay.clearWebServer()

            self.overlays.removeValue(forKey: browser_uuid)

            self.hidden = false

            call.resolve()
        }
    }

    @objc func getSnapshot(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let browser_uuid = call.getString("id") else {
                call.reject("Must provide a browser id")
                return
            }

            guard let overlay = self.overlays[browser_uuid] else {
                call.reject("Can't find browser matching id")
                return
            }

            if (overlay != nil) {
                if (overlay.webview != nil) {
                    let offset: CGPoint = (overlay.webview?.scrollView.contentOffset)!
                    overlay.webview?.scrollView.setContentOffset(offset, animated: false)

                    overlay.webview?.takeSnapshot(with: nil) {image, error in
                        if let image = image {
                            guard let jpeg = image.jpegData(compressionQuality: 1) else {
                                return
                            }
                            let base64String = jpeg.base64EncodedString()
                            call.resolve(["src": base64String])
                        } else {
                            call.resolve(["src": ""])
                        }
                    }
                }
                else {
                    call.resolve(["src": ""])
                }
            }
            else {
                call.resolve(["src": ""])
            }
        }
    }

    @objc func updateDimensions(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let browser_uuid = call.getString("id") else {
                call.reject("Must provide a browser id")
                return
            }

            guard let overlay = self.overlays[browser_uuid] else {
                call.reject("Can't find browser matching id")
                return
            }

            let dimensions = call.getObject("dimensions") ?? [:]
            self.width = CGFloat(dimensions["width"] as? Float ?? 0)
            self.height = CGFloat(dimensions["height"] as? Float ?? 0)
            self.x = CGFloat(dimensions["x"] as? Float ?? 0)
            self.y = CGFloat(dimensions["y"] as? Float ?? 0)

            if (!self.fullscreen) {
                let rect = CGRect(x: self.x, y: self.y, width: self.width, height: self.height)
                overlay.view.frame = rect
            }
            else {
                let width = UIScreen.main.bounds.width
                let height = UIScreen.main.bounds.height
                let rect = CGRect(x: 0, y: 0, width: width, height: height)
                overlay.view.frame = rect
            }

            if (overlay.topSafeArea != nil && overlay.closeFullscreenButton != nil) {
                overlay.closeFullscreenButton.frame = CGRect(x: UIScreen.main.bounds.width - 60, y: overlay.topSafeArea + 20, width: 40, height: 40)
            }
            
            if (self.hidden) {
                overlay.notify("updateSnapshot", data: [:])
            }

            call.resolve()
        }
    }

    @objc func show(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let browser_uuid = call.getString("id") else {
                call.reject("Must provide a browser id")
                return
            }

            guard let overlay = self.overlays[browser_uuid] else {
                call.reject("Can't find browser matching id")
                return
            }

            self.hidden = false
            if (overlay != nil) {
                overlay.view.isHidden = false
            }
            call.resolve()
        }
    }

    @objc func hide(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let browser_uuid = call.getString("id") else {
                call.reject("Must provide a browser id")
                return
            }

            guard let overlay = self.overlays[browser_uuid] else {
                call.reject("Can't find browser matching id")
                return
            }

            self.hidden = true
            if (overlay != nil) {
                overlay.view.isHidden = true
            }
            call.resolve()
        }
    }

    @objc func evaluateJavaScript(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let browser_uuid = call.getString("id") else {
                call.reject("Must provide a browser id")
                return
            }

            guard let overlay = self.overlays[browser_uuid] else {
                call.reject("Can't find browser matching id")
                return
            }

            guard let javascript = call.getString("javascript") else {
                call.reject("Must provide javascript string")
                return
            }
            if (overlay != nil) {
                if (overlay.webview != nil) {
                    func eval(completionHandler: @escaping (_ response: String?) -> Void) {
                        overlay.webview?.evaluateJavaScript(String(javascript)) { (value, error) in
                            if error != nil {
                                call.reject(error?.localizedDescription ?? "unknown error")
                            }
                            else if let valueName = value as? String {
                                completionHandler(valueName)
                            }
                        }
                    }

                    eval(completionHandler: { response in
                        call.resolve(["result": response as Any])
                    })
                }
                else {
                    call.resolve(["result": ""])
                }
            }
            else {
                call.resolve(["result": ""])
            }
        }
    }

    @objc func toggleFullscreen(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let browser_uuid = call.getString("id") else {
                call.reject("Must provide a browser id")
                return
            }

            guard let overlay = self.overlays[browser_uuid] else {
                call.reject("Can't find browser matching id")
                return
            }

            if (overlay != nil) {
                if (self.fullscreen) {
                    let rect = CGRect(x: self.x, y: self.y, width: self.width, height: self.height)
                    overlay.view.frame = rect
                    self.fullscreen = false
                    overlay.closeFullscreenButton.isHidden = true
                }
                else {
                    let width = UIScreen.main.bounds.width
                    let height = UIScreen.main.bounds.height
                    let rect = CGRect(x: 0, y: 0, width: width, height: height)
                    overlay.view.frame = rect
                    self.fullscreen = true
                    overlay.closeFullscreenButton.isHidden = false
                }
                if (call != nil) {
                    call.resolve()
                }
            }
        }
    }

    @objc func goBack(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let browser_uuid = call.getString("id") else {
                call.reject("Must provide a browser id")
                return
            }

            guard let overlay = self.overlays[browser_uuid] else {
                call.reject("Can't find browser matching id")
                return
            }

            if (overlay != nil) {
                overlay.webview?.goBack()
                call.resolve()
            }
        }
    }

    @objc func goForward(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let browser_uuid = call.getString("id") else {
                call.reject("Must provide a browser id")
                return
            }

            guard let overlay = self.overlays[browser_uuid] else {
                call.reject("Can't find browser matching id")
                return
            }

            if (overlay != nil) {
                overlay.webview?.goForward()
                call.resolve()
            }
        }
    }

    @objc func reload(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let browser_uuid = call.getString("id") else {
                call.reject("Must provide a browser id")
                return
            }

            guard let overlay = self.overlays[browser_uuid] else {
                call.reject("Can't find browser matching id")
                return
            }

            if (overlay != nil) {
                overlay.webview?.reload()
                call.resolve()
            }
        }
    }

    @objc func loadUrl(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let browser_uuid = call.getString("id") else {
                call.reject("Must provide a browser id")
                return
            }

            guard let overlay = self.overlays[browser_uuid] else {
                call.reject("Can't find browser matching id")
                return
            }

            if (overlay != nil) {
                let url = call.getString("url") ?? ""
                overlay.loadUrlCall = call
                overlay.loadUrl(URL(string: url)!)
            }
        }
    }

    @objc func handleNavigationEvent(_ call: CAPPluginCall) {
        guard let browser_uuid = call.getString("id") else {
            call.reject("Must provide a browser id")
            return
        }

        guard let overlay = self.overlays[browser_uuid] else {
            call.reject("Can't find browser matching id")
            return
        }

        if (overlay.currentDecisionHandler != nil) {
            if (call.getBool("allow") ?? true) {
                overlay.currentDecisionHandler!(.allow)
            }
            else {
                overlay.currentDecisionHandler!(.cancel)
                overlay.notify("pageLoaded", data: [:])
            }
            overlay.currentDecisionHandler = nil
            call.resolve()
        }
    }
}
