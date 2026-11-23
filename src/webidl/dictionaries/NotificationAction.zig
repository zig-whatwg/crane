//! WebIDL dictionary: NotificationAction
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const NotificationAction = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    action: runtime.DOMString,
    title: runtime.DOMString,
    navigate: ?runtime.USVString = null,
    icon: ?runtime.USVString = null,
};
