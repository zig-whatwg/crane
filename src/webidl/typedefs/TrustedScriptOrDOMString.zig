//! WebIDL typedef: TrustedScriptOrDOMString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const TrustedScriptOrDOMString = union(enum) {
    trusted_script: *runtime.Instance,
    domstring: runtime.DOMString,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "trusted_script", .kind = .{ .interface = "TrustedScript" } },
        .{ .field = "domstring", .kind = .string },
    };
};
