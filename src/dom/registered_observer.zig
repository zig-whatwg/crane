//! Registered Observer
//!
//! Represents a registered mutation observer.
//! Spec: https://dom.spec.whatwg.org/#registered-observer

const std = @import("std");
const handles = @import("handles.zig");

/// A registered observer consists of an observer (a MutationObserver object)
/// and options (a MutationObserverInit dictionary).
pub const RegisteredObserver = struct {
    /// The observer object (typed handle to avoid circular import with MutationObserver)
    observer: *handles.MutationObserverHandle,

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

    /// Get the observer as an anyopaque pointer (for legacy interop)
    pub fn getObserverPtr(self: *const RegisteredObserver) *anyopaque {
        return handles.mutationObserverToAnyopaque(self.observer).?;
    }

    /// Create from an anyopaque observer pointer
    pub fn initFromPtr(observer_ptr: *anyopaque, options: Options) RegisteredObserver {
        return .{
            .observer = handles.anyopaqueToMutationObserver(observer_ptr).?,
            .options = options,
        };
    }
};
