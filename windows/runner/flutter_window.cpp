#include "flutter_window.h"

#include <windows.h>
#include <shellapi.h>
#include <strsafe.h>
#include <memory>

#include "flutter/generated_plugin_registrant.h"
#include "flutter/method_channel.h"
#include "flutter/standard_method_codec.h"

#include <shlwapi.h> 
#pragma comment(lib, "shlwapi.lib") 

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
void StartProxy();
void StopProxy();
bool IsProxyRunning();
void SetupMethodChannel(flutter::FlutterViewController* controller);

PROCESS_INFORMATION proxyProcessInfo;

bool isProxyRunning = false;

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {
    StopProxy(); 
}

bool FlutterWindow::OnCreate() {
    if (!Win32Window::OnCreate()) {
        return false;
    }

    RECT frame = GetClientArea();

    flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
        frame.right - frame.left, frame.bottom - frame.top, project_);

    if (!flutter_controller_->engine() || !flutter_controller_->view()) {
        return false;
    }

    RegisterPlugins(flutter_controller_->engine());
    SetChildContent(flutter_controller_->view()->GetNativeWindow());

    SetupMethodChannel(flutter_controller_.get());

    flutter_controller_->engine()->SetNextFrameCallback([&]() {
        this->Show();
        });

    flutter_controller_->ForceRedraw();

    return true;
}

void FlutterWindow::OnDestroy() {
    StopProxy();
    if (flutter_controller_) {
        flutter_controller_ = nullptr;
    }

    Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
    WPARAM const wparam,
    LPARAM const lparam) noexcept {

    if (flutter_controller_) {
        std::optional<LRESULT> result =
            flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
        if (result) {
            return *result;
        }
    }

    switch (message) {  
        case WM_FONTCHANGE:
            flutter_controller_->engine()->ReloadSystemFonts();
            break;
    }

    return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

std::wstring GetBinaryPath() {
    WCHAR path[MAX_PATH];
    if (GetModuleFileName(NULL, path, MAX_PATH) == 0) {
        return L"";
    }

    PathRemoveFileSpec(path); 
    PathAppend(path, L"resources\\server.exe");

    return std::wstring(path);
}

void SetSystemProxy(const std::wstring& proxyAddress) {
    HKEY hKey;
    LONG result = RegOpenKeyEx(HKEY_CURRENT_USER,
                               L"Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings",
                               0,
                               KEY_SET_VALUE,
                               &hKey);
    if (result == ERROR_SUCCESS) {
        DWORD proxyEnable = 1;
        RegSetValueEx(hKey, L"ProxyEnable", 0, REG_DWORD, (const BYTE*)&proxyEnable, sizeof(proxyEnable));

        // Calculate size of the proxyAddress string in bytes including the null terminator
        DWORD proxyAddressSize = static_cast<DWORD>((proxyAddress.size() + 1) * sizeof(wchar_t));

        // Set HTTP Proxy
        RegSetValueEx(hKey, L"ProxyServer", 0, REG_SZ, (const BYTE*)proxyAddress.c_str(), proxyAddressSize);

        // Set Auto Detect (0 = Disabled)
        DWORD autoDetect = 0;
        RegSetValueEx(hKey, L"AutoDetectSettings", 0, REG_DWORD, (const BYTE*)&autoDetect, sizeof(autoDetect));

        RegCloseKey(hKey);

        // Notify Windows that settings have changed
        ::SendMessageTimeout(HWND_BROADCAST, WM_SETTINGCHANGE, 0, (LPARAM)L"Environment", SMTO_ABORTIFHUNG, 5000, nullptr);
    } else {
        std::wcerr << L"Failed to open registry key. Error code: " << result << std::endl;
    }
}

void UnsetSystemProxy() {
    HKEY hKey;
    LONG result = RegOpenKeyEx(HKEY_CURRENT_USER,
                               L"Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings",
                               0,
                               KEY_SET_VALUE,
                               &hKey);
    if (result == ERROR_SUCCESS) {
        DWORD proxyEnable = 0;
        RegSetValueEx(hKey, L"ProxyEnable", 0, REG_DWORD, (const BYTE*)&proxyEnable, sizeof(proxyEnable));

        // Remove HTTP Proxy
        RegDeleteValue(hKey, L"ProxyServer");

        // Set Auto Detect (1 = Enabled)
        DWORD autoDetect = 1;
        RegSetValueEx(hKey, L"AutoDetectSettings", 0, REG_DWORD, (const BYTE*)&autoDetect, sizeof(autoDetect));

        RegCloseKey(hKey);

        // Notify Windows that settings have changed
        ::SendMessageTimeout(HWND_BROADCAST, WM_SETTINGCHANGE, 0, (LPARAM)L"Environment", SMTO_ABORTIFHUNG, 5000, nullptr);
    } else {
        std::wcerr << L"Failed to open registry key. Error code: " << result << std::endl;
    }
}

void LogToConsole(const std::wstring& message) {
    std::wcout << message << std::endl;
}

void StartProxy(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result,
    const flutter::EncodableMap& arguments) {

    if (isProxyRunning) {
        result->Success(flutter::EncodableValue("Proxy server is already running."));
        return;
    }

    std::wstring binaryPath = GetBinaryPath();
    if (binaryPath.empty()) {
        result->Error("BINARY_NOT_FOUND", "Binary path is empty. Cannot start the proxy server.");
        return;
    }

    std::wstring cmdLine = L"\"" + binaryPath + L"\"";

    auto paramsIt = arguments.find(flutter::EncodableValue("params"));

    if (paramsIt != arguments.end()) {
        const auto* paramsStr = std::get_if<std::string>(&paramsIt->second);
        if (paramsStr) {
            std::wstring paramsWstr(paramsStr->begin(), paramsStr->end());
            cmdLine += L" " + paramsWstr;
        } else {
            result->Error("INVALID_PARAMETER_TYPE", "Expected 'params' to be a string.");
            return;
        }
    }

    LogToConsole(cmdLine);

    STARTUPINFO si = { sizeof(si) };
    PROCESS_INFORMATION pi = {0};

    if (!CreateProcess(nullptr, &cmdLine[0], nullptr, nullptr, FALSE, 0, nullptr, nullptr, &si, &pi)) {
        result->Error("PROCESS_START_ERROR", "Failed to start proxy server.");
        return;
    }

    proxyProcessInfo = pi;
    isProxyRunning = true;

    Sleep(1000);

    DWORD exitCode;
    if (GetExitCodeProcess(pi.hProcess, &exitCode) && exitCode == STILL_ACTIVE) {
        SetSystemProxy(L"127.0.0.1:8080");
        result->Success(flutter::EncodableValue("Proxy server launched successfully."));
    } else {
        result->Error("PROCESS_START_ERROR", "Failed to confirm that the proxy server is running.");
        isProxyRunning = false;

        // Clean up handles
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
    }
}

void StopProxy() {
    if (!IsProxyRunning()) return;

    if (proxyProcessInfo.hProcess != NULL && proxyProcessInfo.hProcess != INVALID_HANDLE_VALUE) {
        if (!TerminateProcess(proxyProcessInfo.hProcess, 0)) {
            DWORD error = GetLastError();
            std::cerr << "StopProxy: TerminateProcess failed. Error code: " << error << std::endl;
        } else {
            std::cout << "StopProxy: TerminateProcess succeeded." << std::endl;
        }
    } else {
        std::cerr << "StopProxy: Invalid process handle." << std::endl;
    }

    // Close handles
    if (proxyProcessInfo.hThread != NULL && proxyProcessInfo.hThread != INVALID_HANDLE_VALUE) {
        if (CloseHandle(proxyProcessInfo.hThread) == 0) {
            DWORD error = GetLastError();
            std::cerr << "StopProxy: CloseHandle for thread handle failed. Error code: " << error << std::endl;
        }
    }

    if (proxyProcessInfo.hProcess != NULL && proxyProcessInfo.hProcess != INVALID_HANDLE_VALUE) {
        if (CloseHandle(proxyProcessInfo.hProcess) == 0) {
            DWORD error = GetLastError();
            std::cerr << "StopProxy: CloseHandle for process handle failed. Error code: " << error << std::endl;
        }
    }

    UnsetSystemProxy();

    isProxyRunning = false;
}

bool IsProxyRunning() {
    return isProxyRunning;
}

void OpenURL(const std::string& url) {
    ShellExecuteA(NULL, "open", url.c_str(), NULL, NULL, SW_SHOWNORMAL);
}



void SetupMethodChannel(flutter::FlutterViewController* controller) {
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        controller->engine()->messenger(), "proxy_bridge",
        &flutter::StandardMethodCodec::GetInstance());

    channel->SetMethodCallHandler(
        [](const flutter::MethodCall<flutter::EncodableValue>& call, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
            if (call.method_name().compare("start_proxy") == 0) {
                const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
                StartProxy(std::move(result), *arguments);
            }
            else if (call.method_name().compare("stop_proxy") == 0) {
                StopProxy();
                result->Success(flutter::EncodableValue("Proxy stopped"));
            }
            else if (call.method_name().compare("is_proxy_running") == 0) {
                result->Success(flutter::EncodableValue(IsProxyRunning()));
            }
            else if (call.method_name().compare("test_service") == 0) {
                OpenURL("https://rutracker.org");
                result->Success(flutter::EncodableValue("Opened test service URL"));
            }
            else if (call.method_name().compare("open_binary") == 0) {
                OpenURL("https://github.com/xvzc/SpoofDPI");
                result->Success(flutter::EncodableValue("Opened binary URL"));
            }
            else if (call.method_name().compare("open_me") == 0) {
                OpenURL("https://github.com/r3pr3ss10n/SpoofDPI-Platform");
                result->Success(flutter::EncodableValue("Opened my URL"));
            }
            else {
                result->NotImplemented();
            }
        });
}
