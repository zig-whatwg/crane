//! WebIDL typedef: HTMLOrSVGImageElement
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const HTMLOrSVGImageElement = union(enum) {
    htmlimage_element: *runtime.Instance,
    svgimage_element: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "htmlimage_element", .kind = .{ .interface = "HTMLImageElement" } },
        .{ .field = "svgimage_element", .kind = .{ .interface = "SVGImageElement" } },
    };
};
