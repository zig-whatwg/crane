//! WebIDL typedef: HTMLCanvasElementOrOffscreenCanvas
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const HTMLCanvasElementOrOffscreenCanvas = union(enum) {
    htmlcanvas_element: *runtime.Instance,
    offscreen_canvas: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "htmlcanvas_element", .kind = .{ .interface = "HTMLCanvasElement" } },
        .{ .field = "offscreen_canvas", .kind = .{ .interface = "OffscreenCanvas" } },
    };
};
