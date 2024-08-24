import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {

    private let channelName = "proxy_bridge"
    private var process: Process?

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    override func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard let flutterViewController = mainFlutterWindow?.contentViewController as? FlutterViewController else {
            fatalError("mainFlutterWindow's contentViewController is not FlutterViewController")
        }
        let methodChannel = FlutterMethodChannel(name: channelName, binaryMessenger: flutterViewController.engine.binaryMessenger)
        
        methodChannel.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "start_proxy":
                self?.startProxy(result: result)
            case "stop_proxy":
                self?.stopProxy(result: result)
            case "is_proxy_running":
                self?.isProxyRunning(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
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
    
    private func isProxyRunning(result: @escaping FlutterResult) {
        let isRunning = (process != nil && process?.isRunning == true)
        result(isRunning)
    }
}
