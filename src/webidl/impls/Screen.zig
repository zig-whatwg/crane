//! Implementation for Screen interface (CSSOM View 4.3; Screen
//! Orientation's `orientation`). Every answer is the window's tab's screen
//! (html.screen_info): a host's emulated device, else the platform's last
//! `screen_changed` report, else its `screenInfo`.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const Screen = interfaces.Screen;

pub const State = Screen.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// The screen of this Screen's window's tab (html.screen_info).
fn screenOf(instance: *runtime.Instance) @import("html").screen_info.Screen {
    const html = @import("html");
    const window = html.user_activation.windowOfRealm(instance.ctx) orelse return html.screen_info.ofRealm(instance.ctx);
    return html.screen_info.ofWindow(window);
}

/// Getter for availWidth (CSSOM View: the available width of the output
/// device's rendering surface).
pub fn get_availWidth(instance: *runtime.Instance) anyerror!i32 {
    return screenOf(instance).avail_width;
}

/// Getter for availHeight
pub fn get_availHeight(instance: *runtime.Instance) anyerror!i32 {
    return screenOf(instance).avail_height;
}

/// Getter for width (CSSOM View: the width of the output device)
pub fn get_width(instance: *runtime.Instance) anyerror!i32 {
    return screenOf(instance).width;
}

/// Getter for height
pub fn get_height(instance: *runtime.Instance) anyerror!i32 {
    return screenOf(instance).height;
}

/// Getter for colorDepth
pub fn get_colorDepth(instance: *runtime.Instance) anyerror!u32 {
    return screenOf(instance).color_depth;
}

/// Getter for pixelDepth
pub fn get_pixelDepth(instance: *runtime.Instance) anyerror!u32 {
    return screenOf(instance).pixel_depth;
}

/// Getter for isExtended
/// Per Window Management spec: whether this is an extended screen
pub fn get_isExtended(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return false; // Not extended by default
}

/// Getter for onchange
pub fn get_onchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for orientation (Screen Orientation, "Extensions to the Screen
/// interface"): the Window's associated ScreenOrientation, made on the
/// first read and initialized then (html.screen_orientation.register). The
/// generated [SameObject] getter caches it and traces it from this Screen
/// (dom.same_object_cache), which the Window's own cache traces in turn, so
/// an `onchange` set on it lives as long as the Window.
pub fn get_orientation(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const html = @import("html");
    const window = html.user_activation.windowOfRealm(instance.ctx) orelse return error.InvalidStateError;
    const orientation = try interfaces.ScreenOrientation.init(instance.ctx.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(orientation);
    try html.screen_orientation.register(orientation, window);
    return orientation;
}

/// Setter for onchange
pub fn set_onchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}
