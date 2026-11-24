//! WebIDL typedef: TrustedHTMLOrDOMString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const TrustedHTMLOrDOMString = union(enum) {
    trusted_html: *runtime.Instance,
    domstring: runtime.DOMString,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "trusted_html", .kind = .{ .interface = "TrustedHTML" } },
        .{ .field = "domstring", .kind = .string },
    };
};
