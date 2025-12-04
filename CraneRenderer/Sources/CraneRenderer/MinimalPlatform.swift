import Crane

/// A platform with all capabilities disabled.
public struct MinimalPlatform: CranePlatform {
    let clipboard: (some ClipboardCapability)? = .none
    let timer: (some TimerCapability)? = .none
    let network: (some NetworkCapability)? = .none
    let storage: (some StorageCapability)? = .none
    let layout: (some LayoutCapability)? = .none
    let ui: (some UICapability)? = .none
    let screen: (some ScreenCapability)? = .none
    let notification: (some NotificationCapability)? = .none
    let push: (some PushCapability)? = .none
    let share: (some ShareCapability)? = .none
    let fileSystem: (some FileSystemCapability)? = .none
    let geolocation: (some GeolocationCapability)? = .none
    let bluetooth: (some BluetoothCapability)? = .none
    let usb: (some USBCapability)? = .none
    let serial: (some SerialCapability)? = .none
    let hid: (some HIDCapability)? = .none
    let nfc: (some NFCCapability)? = .none
    let deviceOrientation: (some DeviceOrientationCapability)? = .none
    let vibration: (some VibrationCapability)? = .none
    let battery: (some BatteryCapability)? = .none
    let wakeLock: (some WakeLockCapability)? = .none
    let webRTC: (some WebRTCCapability)? = .none
    let media: (some MediaCapability)? = .none
    let audio: (some AudioCapability)? = .none
    let speech: (some SpeechCapability)? = .none
    let gamepad: (some GamepadCapability)? = .none
    let sensor: (some SensorCapability)? = .none
    let credentials: (some CredentialsCapability)? = .none
    let webAuthn: (some WebAuthnCapability)? = .none
    let permissions: (some PermissionsCapability)? = .none
    let payment: (some PaymentCapability)? = .none
}