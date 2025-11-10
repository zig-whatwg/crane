//! Attr interface per WHATWG DOM Standard

const std = @import("std");
const webidl = @import("webidl");

pub const Attr = webidl.interface(struct {
    name: []const u8,
    value: []const u8,
});
