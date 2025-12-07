//! WebIDL dictionary: NotificationAction
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const NotificationAction = struct {
    action: runtime.DOMString,
    title: runtime.DOMString,
    navigate: ?runtime.USVString = null,
    icon: ?runtime.USVString = null,
};
