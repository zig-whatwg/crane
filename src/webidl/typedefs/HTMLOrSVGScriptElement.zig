//! WebIDL typedef: HTMLOrSVGScriptElement
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const HTMLOrSVGScriptElement = union(enum) {
    htmlscript_element: *runtime.Instance,
    svgscript_element: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "htmlscript_element", .kind = .{ .interface = "HTMLScriptElement" } },
        .{ .field = "svgscript_element", .kind = .{ .interface = "SVGScriptElement" } },
    };
};
