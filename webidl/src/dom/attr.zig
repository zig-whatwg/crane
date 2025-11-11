//! Attr interface per WHATWG DOM Standard

const std = @import("std");
const webidl = @import("webidl");
const Node = @import("node").Node;

/// DOM Spec: interface Attr : Node
pub const Attr = webidl.interface(struct {
    pub const extends = Node;

    name: []const u8,
    value: []const u8,
}, .{
    .exposed = &.{.Window},
});
