//! WebIDL typedef: CustomElementConstructorOrUndefined
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const callbacks = @import("callbacks");
const typedefs = @import("root.zig");

pub const CustomElementConstructorOrUndefined = union(enum) {
    custom_element_constructor: callbacks.CustomElementConstructor,
    undefined: void,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "custom_element_constructor", .kind = .callback_function },
        .{ .field = "undefined", .kind = .undefined },
    };
};
