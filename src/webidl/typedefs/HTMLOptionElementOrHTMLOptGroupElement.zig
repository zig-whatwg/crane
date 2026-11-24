//! WebIDL typedef: HTMLOptionElementOrHTMLOptGroupElement
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const HTMLOptionElementOrHTMLOptGroupElement = union(enum) {
    htmloption_element: *runtime.Instance,
    htmlopt_group_element: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "htmloption_element", .kind = .{ .interface = "HTMLOptionElement" } },
        .{ .field = "htmlopt_group_element", .kind = .{ .interface = "HTMLOptGroupElement" } },
    };
};
