//! WebIDL dictionary: NotificationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const NotificationOptions = struct {
    dir: ?*const anyopaque = null,
    lang: ?runtime.DOMString = null,
    body: ?runtime.DOMString = null,
    navigate: ?runtime.USVString = null,
    tag: ?runtime.DOMString = null,
    image: ?runtime.USVString = null,
    icon: ?runtime.USVString = null,
    badge: ?runtime.USVString = null,
    vibrate: ?*const anyopaque = null,
    timestamp: ?*const anyopaque = null,
    renotify: ?bool = null,
    silent: ?bool = null,
    requireInteraction: ?bool = null,
    data: ?*const anyopaque = null,
    actions: ?*const anyopaque = null,
};
