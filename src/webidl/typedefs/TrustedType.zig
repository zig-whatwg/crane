//! WebIDL typedef: TrustedType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const TrustedType = union(enum) {
    trusted_html: *runtime.Instance,
    trusted_script: *runtime.Instance,
    trusted_script_url: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "trusted_html", .kind = .{ .interface = "TrustedHTML" } },
        .{ .field = "trusted_script", .kind = .{ .interface = "TrustedScript" } },
        .{ .field = "trusted_script_url", .kind = .{ .interface = "TrustedScriptURL" } },
    };
};
