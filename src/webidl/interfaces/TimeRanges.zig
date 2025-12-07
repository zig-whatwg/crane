//! Generated from: html.idl
//! Generated at: 2025-12-07T19:32:59Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const TimeRangesImpl = @import("impls").TimeRanges;
const mixins = @import("mixins");

pub const TimeRanges = struct {
    pub const Meta = struct {
        pub const name = "TimeRanges";
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "start", "call_start", 1 },
            .{ "end", "call_end", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "start",
            "end",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            _internal: ?*TimeRangesImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_length = &get_length,

        .call_end = &call_end,
        .call_start = &call_start,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TimeRangesImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TimeRangesImpl.deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try TimeRangesImpl.get_length(instance);
    }

    pub fn call_start(instance: *runtime.Instance, index: u32) anyerror!f64 {
        
        return try TimeRangesImpl.call_start(instance, index);
    }

    pub fn call_end(instance: *runtime.Instance, index: u32) anyerror!f64 {
        
        return try TimeRangesImpl.call_end(instance, index);
    }

};
