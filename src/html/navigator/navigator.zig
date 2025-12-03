//! Navigator Interface
//!
//! HTML Standard § 8.8 - The Navigator object
//! https://html.spec.whatwg.org/#the-navigator-object
//!
//! The Navigator interface provides access to browser/user agent information
//! and various hardware APIs through pluggable backends.

const std = @import("std");
const Allocator = std.mem.Allocator;

const NavigatorId = @import("navigator_id.zig").NavigatorId;
const NavigatorLanguage = @import("navigator_language.zig").NavigatorLanguage;
const NavigatorOnLine = @import("navigator_online.zig").NavigatorOnLine;
const NavigatorConcurrentHardware = @import("navigator_concurrent_hardware.zig").NavigatorConcurrentHardware;
const NavigatorContentUtils = @import("navigator_content_utils.zig").NavigatorContentUtils;
const NavigatorCookies = @import("navigator_cookies.zig").NavigatorCookies;
const NavigatorPlugins = @import("navigator_plugins.zig").NavigatorPlugins;

// Hardware API types
const geolocation_mod = @import("geolocation/root.zig");
const Geolocation = geolocation_mod.Geolocation;
const GeolocationBackend = geolocation_mod.GeolocationBackend;

const media_devices_mod = @import("media_devices/root.zig");
const MediaDevices = media_devices_mod.MediaDevices;
const MediaDevicesBackend = media_devices_mod.MediaDevicesBackend;

const clipboard_mod = @import("clipboard/root.zig");
const Clipboard = clipboard_mod.Clipboard;
const ClipboardBackend = clipboard_mod.ClipboardBackend;

const credentials_mod = @import("credentials/root.zig");
const CredentialsContainer = credentials_mod.CredentialsContainer;

const bluetooth_mod = @import("bluetooth/root.zig");
const Bluetooth = bluetooth_mod.Bluetooth;
const BluetoothBackend = bluetooth_mod.BluetoothBackend;

const usb_mod = @import("usb/root.zig");
const USB = usb_mod.USB;
const USBBackend = usb_mod.USBBackend;

const serial_mod = @import("serial/root.zig");
const Serial = serial_mod.Serial;
const SerialBackend = serial_mod.SerialBackend;

const hid_mod = @import("hid/root.zig");
const HID = hid_mod.HID;
const HIDBackend = hid_mod.HIDBackend;

const battery_mod = @import("battery/root.zig");
const BatteryManager = battery_mod.BatteryManager;
const BatteryBackend = battery_mod.BatteryBackend;

const storage_manager_mod = @import("storage_manager/root.zig");
const StorageManager = storage_manager_mod.StorageManager;

/// Backend configuration for Navigator
/// Allows embedders to plug in real implementations
pub const NavigatorBackend = struct {
    /// Geolocation backend
    geolocation: ?*GeolocationBackend = null,

    /// Media devices backend
    media_devices: ?*MediaDevicesBackend = null,

    /// Clipboard backend
    clipboard: ?*ClipboardBackend = null,

    /// Bluetooth backend
    bluetooth: ?*BluetoothBackend = null,

    /// USB backend
    usb: ?*USBBackend = null,

    /// Serial backend
    serial: ?*SerialBackend = null,

    /// HID backend
    hid: ?*HIDBackend = null,

    /// Battery backend
    battery: ?*BatteryBackend = null,
};

/// Navigator interface implementation
/// Spec: HTML Standard § 8.8
///
/// Exposed to: Window
///
/// The Navigator interface aggregates various mixins and hardware APIs.
/// All hardware APIs use pluggable backends - by default returning
/// "not supported" or "permission denied".
pub const Navigator = struct {
    allocator: Allocator,

    // ========================================================================
    // Mixins
    // ========================================================================

    /// NavigatorID mixin (appCodeName, appName, userAgent, etc.)
    id: NavigatorId,

    /// NavigatorLanguage mixin (language, languages)
    language: NavigatorLanguage,

    /// NavigatorOnLine mixin (onLine)
    online: NavigatorOnLine,

    /// NavigatorConcurrentHardware mixin (hardwareConcurrency)
    concurrent_hardware: NavigatorConcurrentHardware,

    /// NavigatorContentUtils mixin (registerProtocolHandler, etc.)
    content_utils: NavigatorContentUtils,

    /// NavigatorCookies mixin (cookieEnabled)
    cookies: NavigatorCookies,

    /// NavigatorPlugins mixin (plugins, mimeTypes, etc.)
    plugins: NavigatorPlugins,

    // ========================================================================
    // Hardware APIs
    // ========================================================================

    /// Geolocation API (navigator.geolocation)
    geolocation: Geolocation,

    /// MediaDevices API (navigator.mediaDevices)
    media_devices: MediaDevices,

    /// Clipboard API (navigator.clipboard)
    clipboard: Clipboard,

    /// Credentials API (navigator.credentials)
    credentials: CredentialsContainer,

    /// Web Bluetooth API (navigator.bluetooth)
    bluetooth: Bluetooth,

    /// WebUSB API (navigator.usb)
    usb: USB,

    /// Web Serial API (navigator.serial)
    serial: Serial,

    /// WebHID API (navigator.hid)
    hid: HID,

    /// Battery Status API (navigator.getBattery())
    battery: BatteryManager,

    /// Storage Manager API (navigator.storage)
    storage: StorageManager,

    const Self = @This();

    /// Initialize Navigator with optional backends
    pub fn init(allocator: Allocator, backends: ?NavigatorBackend) !*Self {
        const navigator = try allocator.create(Self);
        errdefer allocator.destroy(navigator);

        // Initialize NavigatorID
        const id = try NavigatorId.init(allocator);
        errdefer {
            var id_mut = id;
            id_mut.deinit();
        }

        // Initialize mixins
        navigator.* = .{
            .allocator = allocator,
            .id = id,
            .language = NavigatorLanguage.init(allocator),
            .online = NavigatorOnLine.init(),
            .concurrent_hardware = NavigatorConcurrentHardware.init(),
            .content_utils = NavigatorContentUtils.init(allocator),
            .cookies = NavigatorCookies.init(),
            .plugins = NavigatorPlugins.init(),

            // Hardware APIs with backends
            .geolocation = Geolocation.init(allocator, if (backends) |b| b.geolocation else null),
            .media_devices = MediaDevices.init(allocator, if (backends) |b| b.media_devices else null),
            .clipboard = Clipboard.init(allocator, if (backends) |b| b.clipboard else null),
            .credentials = CredentialsContainer.init(allocator),
            .bluetooth = Bluetooth.init(allocator, if (backends) |b| b.bluetooth else null),
            .usb = USB.init(allocator, if (backends) |b| b.usb else null),
            .serial = Serial.init(allocator, if (backends) |b| b.serial else null),
            .hid = HID.init(allocator, if (backends) |b| b.hid else null),
            .battery = BatteryManager.init(allocator, if (backends) |b| b.battery else null),
            .storage = StorageManager.init(allocator),
        };

        return navigator;
    }

    /// Clean up Navigator resources
    pub fn deinit(self: *Self) void {
        self.id.deinit();
        self.language.deinit();
        self.content_utils.deinit();
        self.geolocation.deinit();
        self.media_devices.deinit();
        self.clipboard.deinit();
        self.credentials.deinit();
        self.bluetooth.deinit();
        self.usb.deinit();
        self.serial.deinit();
        self.hid.deinit();
        self.battery.deinit();
        self.storage.deinit();
        self.allocator.destroy(self);
    }

    // ========================================================================
    // NavigatorID accessors
    // ========================================================================

    pub fn getAppCodeName(self: *const Self) []const u8 {
        return self.id.getAppCodeName();
    }

    pub fn getAppName(self: *const Self) []const u8 {
        return self.id.getAppName();
    }

    pub fn getAppVersion(self: *const Self) []const u8 {
        return self.id.getAppVersion();
    }

    pub fn getPlatform(self: *const Self) []const u8 {
        return self.id.getPlatform();
    }

    pub fn getProduct(self: *const Self) []const u8 {
        return self.id.getProduct();
    }

    pub fn getProductSub(self: *const Self) []const u8 {
        return self.id.getProductSub();
    }

    pub fn getUserAgent(self: *const Self) []const u8 {
        return self.id.getUserAgent();
    }

    pub fn getVendor(self: *const Self) []const u8 {
        return self.id.getVendor();
    }

    pub fn getVendorSub(self: *const Self) []const u8 {
        return self.id.getVendorSub();
    }

    pub fn getOscpu(self: *const Self) []const u8 {
        return self.id.getOscpu();
    }

    pub fn taintEnabled(self: *const Self) bool {
        return self.id.taintEnabled();
    }

    // ========================================================================
    // NavigatorLanguage accessors
    // ========================================================================

    pub fn getLanguage(self: *const Self) []const u8 {
        return self.language.getLanguage();
    }

    pub fn getLanguages(self: *const Self) []const []const u8 {
        return self.language.getLanguages();
    }

    // ========================================================================
    // NavigatorOnLine accessors
    // ========================================================================

    pub fn isOnLine(self: *const Self) bool {
        return self.online.isOnLine();
    }

    // ========================================================================
    // NavigatorConcurrentHardware accessors
    // ========================================================================

    pub fn getHardwareConcurrency(self: *const Self) usize {
        return self.concurrent_hardware.getConcurrency();
    }

    // ========================================================================
    // NavigatorCookies accessors
    // ========================================================================

    pub fn isCookieEnabled(self: *const Self) bool {
        return self.cookies.isCookieEnabled();
    }

    // ========================================================================
    // NavigatorPlugins accessors
    // ========================================================================

    pub fn javaEnabled(self: *const Self) bool {
        return self.plugins.javaEnabled();
    }

    pub fn isPdfViewerEnabled(self: *const Self) bool {
        return self.plugins.isPdfViewerEnabled();
    }

    // ========================================================================
    // Hardware API accessors
    // ========================================================================

    /// Get the Geolocation API object
    pub fn getGeolocation(self: *Self) *Geolocation {
        return &self.geolocation;
    }

    /// Get the MediaDevices API object
    pub fn getMediaDevices(self: *Self) *MediaDevices {
        return &self.media_devices;
    }

    /// Get the Clipboard API object
    pub fn getClipboard(self: *Self) *Clipboard {
        return &self.clipboard;
    }

    /// Get the Credentials API object
    pub fn getCredentials(self: *Self) *CredentialsContainer {
        return &self.credentials;
    }

    /// Get the Bluetooth API object
    pub fn getBluetooth(self: *Self) *Bluetooth {
        return &self.bluetooth;
    }

    /// Get the USB API object
    pub fn getUsb(self: *Self) *USB {
        return &self.usb;
    }

    /// Get the Serial API object
    pub fn getSerial(self: *Self) *Serial {
        return &self.serial;
    }

    /// Get the HID API object
    pub fn getHid(self: *Self) *HID {
        return &self.hid;
    }

    /// Get the Battery Manager (returns a Promise in JS)
    /// Spec: navigator.getBattery()
    pub fn getBattery(self: *Self) *BatteryManager {
        return &self.battery;
    }

    /// Get the Storage Manager
    /// Spec: navigator.storage
    pub fn getStorage(self: *Self) *StorageManager {
        return &self.storage;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Navigator - init and deinit" {
    const allocator = std.testing.allocator;

    const navigator = try Navigator.init(allocator, null);
    defer navigator.deinit();

    // Check NavigatorID
    try std.testing.expectEqualStrings("Mozilla", navigator.getAppCodeName());
    try std.testing.expectEqualStrings("Netscape", navigator.getAppName());
    try std.testing.expectEqualStrings("Gecko", navigator.getProduct());

    // Check NavigatorLanguage
    try std.testing.expectEqualStrings("en-US", navigator.getLanguage());

    // Check NavigatorOnLine
    try std.testing.expect(navigator.isOnLine());

    // Check NavigatorConcurrentHardware
    try std.testing.expect(navigator.getHardwareConcurrency() >= 1);

    // Check NavigatorCookies
    try std.testing.expect(navigator.isCookieEnabled());

    // Check NavigatorPlugins
    try std.testing.expect(!navigator.javaEnabled());
    try std.testing.expect(navigator.isPdfViewerEnabled());
}

test "Navigator - hardware APIs accessible" {
    const allocator = std.testing.allocator;

    const navigator = try Navigator.init(allocator, null);
    defer navigator.deinit();

    // All hardware APIs should be accessible
    _ = navigator.getGeolocation();
    _ = navigator.getMediaDevices();
    _ = navigator.getClipboard();
    _ = navigator.getCredentials();
    _ = navigator.getBluetooth();
    _ = navigator.getUsb();
    _ = navigator.getSerial();
    _ = navigator.getHid();
    _ = navigator.getBattery();
    _ = navigator.getStorage();
}
