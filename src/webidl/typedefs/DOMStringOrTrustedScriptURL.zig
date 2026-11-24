//! WebIDL typedef: DOMStringOrTrustedScriptURL
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const DOMStringOrTrustedScriptURL = union(enum) {
    domstring: runtime.DOMString,
    trusted_script_url: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring", .kind = .string },
        .{ .field = "trusted_script_url", .kind = .{ .interface = "TrustedScriptURL" } },
    };
};
