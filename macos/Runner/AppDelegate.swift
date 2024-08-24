import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {

    private let channelName = "proxy_bridge"
    private var process: Process?
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?

    override func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard let flutterViewController = mainFlutterWindow?.contentViewController as? FlutterViewController else {
            fatalError("mainFlutterWindow's contentViewController is not FlutterViewController")
        }
        
        mainWindow = mainFlutterWindow
        
        let methodChannel = FlutterMethodChannel(name: channelName, binaryMessenger: flutterViewController.engine.binaryMessenger)
        
        methodChannel.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "start_proxy":
                self?.startProxy(result: result)
            case "stop_proxy":
                self?.stopProxy(result: result)
            case "is_proxy_running":
                self?.handleIsProxyRunning(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        setupTrayIcon()
        updateTrayMenu()
    }
    
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        NSApp.setActivationPolicy(.accessory)
        return false
    }
    
    private func setupTrayIcon() {
        let statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Proxy Service")
            button.action = #selector(statusBarIconClicked)
        }
    }
    
    private func updateTrayMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Show App", action: #selector(showApp), keyEquivalent: "H"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "Q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func statusBarIconClicked() {
        statusItem?.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    
    @objc private func showApp() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
                DispatchQueue.main.async {
                    NSApp.windows.first?.orderFrontRegardless()
       }
    }
    
    @objc private func quitApp() {
        stopProxy(result: { _ in
            NSApp.terminate(nil)
        })
    }
    
    private func startProxy(result: @escaping FlutterResult) {
        let binaryPath = Bundle.main.path(forResource: "spoofdpi", ofType: "")
        
        guard let path = binaryPath else {
            result(FlutterError(code: "BINARY_NOT_FOUND", message: "spoofdpi binary not found", details: nil))
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--enable-doh", "--window-size", "0"]
        
        do {
            try process.run()
            self.process = process
            result("Proxy service started")
        } catch {
            result(FlutterError(code: "PROCESS_START_ERROR", message: "Failed to start proxy process", details: error.localizedDescription))
        }
    }
    
    private func stopProxy(result: @escaping FlutterResult) {
        process?.terminate()
        process = nil
        result("Proxy service stopped")
    }
    
    private func isProxyRunning() -> Bool {
        return (process != nil && process?.isRunning == true)
    }
    
    private func handleIsProxyRunning(result: @escaping FlutterResult) {
        let isRunning = isProxyRunning()
        result(isRunning)
    }
}
