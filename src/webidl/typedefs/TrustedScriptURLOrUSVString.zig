//! WebIDL typedef: TrustedScriptURLOrUSVString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const TrustedScriptURLOrUSVString = union(enum) {
    trusted_script_url: *runtime.Instance,
    usvstring: runtime.USVString,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "trusted_script_url", .kind = .{ .interface = "TrustedScriptURL" } },
        .{ .field = "usvstring", .kind = .string },
    };
};
