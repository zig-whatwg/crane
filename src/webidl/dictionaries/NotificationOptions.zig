//! WebIDL dictionary: NotificationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const NotificationAction = @import("NotificationAction.zig").NotificationAction;

pub const NotificationOptions = struct {
    dir: ?enums.NotificationDirection = null,
    lang: ?runtime.DOMString = null,
    body: ?runtime.DOMString = null,
    navigate: ?runtime.USVString = null,
    tag: ?runtime.DOMString = null,
    image: ?runtime.USVString = null,
    icon: ?runtime.USVString = null,
    badge: ?runtime.USVString = null,
    vibrate: ?typedefs.VibratePattern = null,
    timestamp: ?typedefs.EpochTimeStamp = null,
    renotify: ?bool = null,
    silent: ?bool = null,
    requireInteraction: ?bool = null,
    data: ?runtime.JSValue = null,
    actions: ?[]const NotificationAction = null,
};
