//! WebIDL dictionary: NotificationAction
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const NotificationAction = struct {
    action: runtime.DOMString,
    title: runtime.DOMString,
    navigate: ?runtime.DOMString = null,
    icon: ?runtime.DOMString = null,
};
