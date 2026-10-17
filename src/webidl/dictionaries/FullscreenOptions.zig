//! WebIDL dictionary: FullscreenOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const FullscreenOptions = struct {
    keyboardLock: ?enums.FullscreenKeyboardLock = null,
    navigationUI: ?enums.FullscreenNavigationUI = null,
    screen: ?*runtime.Instance = null,
};
