//! Registered Observer
//!
//! Represents a registered mutation observer.
//! Spec: https://dom.spec.whatwg.org/#registered-observer

const std = @import("std");

/// A registered observer consists of an observer (a MutationObserver object)
/// and options (a MutationObserverInit dictionary).
pub const RegisteredObserver = struct {
    /// The observer object
    observer: *anyopaque,

    /// Options for observation
    options: Options,

    pub const Options = struct {
        child_list: bool = false,
        attributes: bool = false,
        character_data: bool = false,
        subtree: bool = false,
        attribute_old_value: bool = false,
        character_data_old_value: bool = false,
        attribute_filter: ?[]const []const u8 = null,
    };
};
