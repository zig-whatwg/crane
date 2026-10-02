//! Auto-generated mixin: NonElementParentNode
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NonElementParentNodeImpl = @import("impls").NonElementParentNode;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Element = @import("interfaces").Element;
const DOMString = @import("typedefs").DOMString;

pub const impl = @import("impls").NonElementParentNode;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "NonElementParentNode")) {
        if (comptime @hasDecl(impls.NonElementParentNode, "installHooks")) impls.NonElementParentNode.installHooks();
    }
}

pub fn call_getElementById(instance: *runtime.Instance, elementId: DOMString) anyerror!?*runtime.Instance {
    return try NonElementParentNodeImpl.call_getElementById(instance, elementId);
}
