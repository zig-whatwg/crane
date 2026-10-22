//! Implementation for HTMLMarqueeElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLMarqueeElement = interfaces.HTMLMarqueeElement;

pub const State = HTMLMarqueeElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try HTMLMarqueeElement.init(ctx.allocator, ctx);
    errdefer HTMLMarqueeElement.deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// HTML 16.3.1: the marquee loop count is a positive HTML integer, or -1.
pub fn get_loop(instance: *runtime.Instance) anyerror!i32 {
    var value = (try interfaces.Element.call_getAttribute(instance, .initInterned("loop"))) orelse return -1;
    defer value.deinit(instance.ctx.allocator);
    const parsed = @import("dom").reflection.parseInteger(value.asSlice()) orelse return -1;
    // Blink and WebKit parse into a signed int; overflow uses the default.
    if (parsed <= 0 or parsed > std.math.maxInt(i32)) return -1;
    return @intCast(parsed);
}

/// Serialize a valid loop value; reject other values without changing the attr.
/// Golden rule 2: Chrome and Safari throw IndexSizeError and serialize even an
/// equal value. Firefox ignores invalid values. This is a longstanding split,
/// not spec lag: HTML5 (2014) already said to ignore invalid/equal values.
/// https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/html/html_marquee_element.cc
/// https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/HTMLMarqueeElement.cpp
/// https://www.w3.org/TR/2014/REC-html5-20141028/obsolete.html#the-marquee-element
pub fn set_loop(instance: *runtime.Instance, value: i32) anyerror!void {
    if (value <= 0 and value != -1) return error.IndexSizeError;
    var buffer: [12]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "{d}", .{value}) catch unreachable;
    try interfaces.Element.call_setAttribute(instance, .initInterned("loop"), .{ .domstring = .initInterned(text) });
}

/// Operation: stop
pub fn call_stop(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: start
pub fn call_start(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}
