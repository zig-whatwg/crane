//! WebIDL dictionary: NotificationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const NotificationOptions = struct {
    dir: ?anyopaque = null,
    lang: ?runtime.DOMString = null,
    body: ?runtime.DOMString = null,
    navigate: ?runtime.DOMString = null,
    tag: ?runtime.DOMString = null,
    image: ?runtime.DOMString = null,
    icon: ?runtime.DOMString = null,
    badge: ?runtime.DOMString = null,
    vibrate: ?anyopaque = null,
    timestamp: ?anyopaque = null,
    renotify: ?bool = null,
    silent: ?anyopaque = null,
    requireInteraction: ?bool = null,
    data: ?anyopaque = null,
    actions: ?anyopaque = null,
};
