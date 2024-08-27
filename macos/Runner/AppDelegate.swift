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
                self?.startProxy(result: result, call: call)
            case "stop_proxy":
                self?.stopProxy(result: result)
            case "is_proxy_running":
                self?.handleIsProxyRunning(result: result)
            case "test_service":
                self?.testService(result: result)
            case "open_binary":
                self?.openBinary(result: result)
            case "open_me":
                self?.openMe(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        setupTrayIcon()
        updateTrayMenu()

        showApp()
    }
    
    private func testService(result: @escaping FlutterResult) {
            openUrl("https://rutracker.org")
            result(nil)
        }
        
        private func openBinary(result: @escaping FlutterResult) {
            openUrl("https://github.com/xvzc/SpoofDPI")
            result(nil)
        }
        
        private func openMe(result: @escaping FlutterResult) {
            openUrl("https://github.com/r3pr3ss10n/SpoofDPI-Platform")
            result(nil)
        }
        
        private func openUrl(_ url: String) {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
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
        
        menu.addItem(NSMenuItem(title: "Show App", action: #selector(showApp), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: ""))
        
        statusItem?.menu = menu
    }
    
    @objc private func statusBarIconClicked() {
        statusItem?.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    
    @objc private func showApp() {
        NSApp.activate(ignoringOtherApps: true)
        
        DispatchQueue.main.async {
            self.mainWindow?.makeKeyAndOrderFront(nil)
        }
    }

    
    @objc private func quitApp() {
        stopProxy(result: { _ in
            NSApp.terminate(nil)
        })
    }
    
    private func getBinaryPath() -> String? {
            var sysInfo = utsname()
            uname(&sysInfo)
            let machine = withUnsafePointer(to: &sysInfo.machine.0) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                    String(cString: $0)
                }
            }

            let isAppleSilicon = machine.hasPrefix("arm")

            let binaryName = isAppleSilicon ? "spoofdpi_arm" : "spoofdpi"
        
            return Bundle.main.path(forResource: binaryName, ofType: "")
        }
    
    private func startProxy(result: @escaping FlutterResult, call: FlutterMethodCall) {
        guard let path = getBinaryPath() else {
            result(FlutterError(code: "BINARY_NOT_FOUND", message: "Appropriate binary not found", details: nil))
            return
        }
        
        guard let args = call.arguments as? [String: Any],
              let params = args["params"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected argument of type Dictionary with key 'params'", details: nil))
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = params.split(separator: " ").map { String($0) }
        
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            self.process = process

            DispatchQueue.global().async {
                sleep(1)

                if self.isProcessRunning() {
                    result("Proxy server launched successfully")
                } else {
                    result(FlutterError(code: "PROCESS_START_ERROR", message: "Failed to confirm that the proxy server is running", details: nil))
                }
            }
        } catch {
            result(FlutterError(code: "PROCESS_START_ERROR", message: "Failed to start proxy process", details: error.localizedDescription))
        }
    }

    private func isProcessRunning() -> Bool {
        return process?.isRunning == true
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
