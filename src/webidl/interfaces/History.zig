//! Generated from: html.idl
//! Generated at: 2025-12-05T20:30:48Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HistoryImpl = @import("impls").History;
const mixins = @import("mixins");
const ScrollRestoration = @import("enums").ScrollRestoration;
const DOMString = @import("typedefs").DOMString;
const USVString = @import("interfaces").USVString;

pub const History = struct {
    pub const Meta = struct {
        pub const name = "History";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", null },
            .{ "scrollRestoration", "get_scrollRestoration", "set_scrollRestoration" },
            .{ "state", "get_state", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "go", "call_go", 0 },
            .{ "back", "call_back", 0 },
            .{ "forward", "call_forward", 0 },
            .{ "pushState", "call_pushState", 2 },
            .{ "replaceState", "call_replaceState", 2 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "go",
            "back",
            "forward",
            "pushState",
            "replaceState",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
            .{ "scrollRestoration", "get_scrollRestoration", "set_scrollRestoration" },
            .{ "state", "get_state", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            scrollRestoration: ScrollRestoration = undefined,
            state: *const anyopaque = undefined,
            _internal: ?*HistoryImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_length = &get_length,
        .get_scrollRestoration = &get_scrollRestoration,
        .get_state = &get_state,

        .set_scrollRestoration = &set_scrollRestoration,

        .call_back = &call_back,
        .call_forward = &call_forward,
        .call_go = &call_go,
        .call_pushState = &call_pushState,
        .call_replaceState = &call_replaceState,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HistoryImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HistoryImpl.deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try HistoryImpl.get_length(instance);
    }

    pub fn get_scrollRestoration(instance: *runtime.Instance) anyerror!ScrollRestoration {
        return try HistoryImpl.get_scrollRestoration(instance);
    }

    pub fn set_scrollRestoration(instance: *runtime.Instance, value: ScrollRestoration) anyerror!void {
        try HistoryImpl.set_scrollRestoration(instance, value);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try HistoryImpl.get_state(instance);
    }

    pub fn call_forward(instance: *runtime.Instance) anyerror!void {
        return try HistoryImpl.call_forward(instance);
    }

    pub fn call_pushState(instance: *runtime.Instance, data: *const anyopaque, unused: DOMString, url: webidl.Opt(?runtime.USVString)) anyerror!void {
        return try HistoryImpl.call_pushState(instance, data, unused, url);
    }

    pub fn call_go(instance: *runtime.Instance, delta: webidl.Opt(i32)) anyerror!void {
        return try HistoryImpl.call_go(instance, delta);
    }

    pub fn call_back(instance: *runtime.Instance) anyerror!void {
        return try HistoryImpl.call_back(instance);
    }

    pub fn call_replaceState(instance: *runtime.Instance, data: *const anyopaque, unused: DOMString, url: webidl.Opt(?runtime.USVString)) anyerror!void {
        return try HistoryImpl.call_replaceState(instance, data, unused, url);
    }
};
