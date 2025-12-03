//! Navigator API Implementation
//!
//! HTML Standard § 8.8 - The Navigator object
//! https://html.spec.whatwg.org/#the-navigator-object
//!
//! This module implements the Navigator interface which provides
//! information about the user agent (browser) and access to various
//! hardware/system APIs through pluggable backends.

const std = @import("std");
const Allocator = std.mem.Allocator;

// Re-export all navigator sub-modules
pub const Navigator = @import("navigator.zig").Navigator;
pub const NavigatorBackend = @import("navigator.zig").NavigatorBackend;
pub const NavigatorId = @import("navigator_id.zig").NavigatorId;
pub const NavigatorLanguage = @import("navigator_language.zig").NavigatorLanguage;
pub const NavigatorOnLine = @import("navigator_online.zig").NavigatorOnLine;
pub const NavigatorConcurrentHardware = @import("navigator_concurrent_hardware.zig").NavigatorConcurrentHardware;
pub const NavigatorContentUtils = @import("navigator_content_utils.zig").NavigatorContentUtils;
pub const NavigatorCookies = @import("navigator_cookies.zig").NavigatorCookies;
pub const NavigatorPlugins = @import("navigator_plugins.zig").NavigatorPlugins;

// Hardware API backends
pub const geolocation = @import("geolocation/root.zig");
pub const media_devices = @import("media_devices/root.zig");
pub const clipboard = @import("clipboard/root.zig");
pub const credentials = @import("credentials/root.zig");
pub const bluetooth = @import("bluetooth/root.zig");
pub const usb = @import("usb/root.zig");
pub const serial = @import("serial/root.zig");
pub const hid = @import("hid/root.zig");
pub const battery = @import("battery/root.zig");
pub const storage_manager = @import("storage_manager/root.zig");

test {
    std.testing.refAllDecls(@This());
}
