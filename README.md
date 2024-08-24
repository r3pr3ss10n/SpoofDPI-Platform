# SpoofDPI-Platform

**WARNING! UNDER DEVELOPMENT!**

SpoofDPI-Platform is designed to help you bypass DPI-based internet restrictions. It acts as a wrapper for the [SpoofDPI application](https://github.com/xvzc/SpoofDPI).

## How to Use

1. **Install the Application**: Download and install the app. Click the "Start Service" button to begin.

2. **With Root Privileges**:
    - If you have root access via [KernelSU](https://github.com/tiann/KernelSU), [Magisk](https://github.com/topjohnwu/Magisk), or [APatch](https://github.com/bmax121/APatch), the application will automatically configure the proxy server for you and disable it upon shutdown. Don't forget to provide app root access before starting service!

3. **Without Root Privileges**:
    - If you do not have root access, you can still use the app. After enabling the service, go to your phone's settings:
        - Navigate to Wi-Fi > Your WI-FI network -> Advanced Settings > Proxy.
        - Set the address provided by the app.

4. **Start Browsing**: You should now be able to browse the internet with fewer restrictions.

## Future Plans

1. Develop MacOS and Windows versions of the application.
2. Implement an in-app VPN service for users without root access.
3. Additional features and improvements (details to be determined).

## Acknowledgements

- Special thanks to [xvzc](https://github.com/xvzc/) for the [SpoofDPI](https://github.com/xvzc/SpoofDPI) application.