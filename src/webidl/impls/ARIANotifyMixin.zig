//! Implementation for the ARIANotifyMixin mixin (ARIA Notify):
//! ariaNotify(), shared by Document and Element.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const ARIANotifyMixin = interfaces.ARIANotifyMixin;

pub const State = ARIANotifyMixin.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// Operation: ariaNotify
pub fn call_ariaNotify(instance: *runtime.Instance, announcement: runtime.DOMString, options: webidl.Opt(dictionaries.AriaNotificationOptions)) anyerror!void {
    _ = instance;
    _ = announcement;
    _ = options;
    return error.NotImplemented;
}
