//! Auto-generated mixin: ARIANotifyMixin
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ARIANotifyMixinImpl = @import("impls").ARIANotifyMixin;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AriaNotificationOptions = @import("dictionaries").AriaNotificationOptions;
const DOMString = @import("typedefs").DOMString;

pub const impl = @import("impls").ARIANotifyMixin;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "ARIANotifyMixin")) {
        if (comptime @hasDecl(impls.ARIANotifyMixin, "installHooks")) impls.ARIANotifyMixin.installHooks();
    }
}

pub fn call_ariaNotify(instance: *runtime.Instance, announcement: runtime.DOMString, options: webidl.Opt(AriaNotificationOptions)) anyerror!void {
    return try ARIANotifyMixinImpl.call_ariaNotify(instance, announcement, options);
}
