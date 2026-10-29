//! CSS Typed OM: image serialization uses CSSStyleValue's retained native data.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
pub const State = interfaces.CSSImageValue.State;
pub const ImplError = error{};
pub const InternalState = struct {};

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = instance;
    _ = allocator;
    _ = StateType;
    _ = args;
}
