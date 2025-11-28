//! Generated from: geolocation.idl
//! Generated at: 2025-11-28T18:57:54Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GeolocationImpl = @import("impls").Geolocation;
const mixins = @import("mixins");
const PositionCallback = @import("callbacks").PositionCallback;
const PositionErrorCallback = @import("callbacks").PositionErrorCallback;
const PositionOptions = @import("dictionaries").PositionOptions;

pub const Geolocation = struct {
    pub const Meta = struct {
        pub const name = "Geolocation";
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getCurrentPosition", "call_getCurrentPosition", 1 },
            .{ "watchPosition", "call_watchPosition", 1 },
            .{ "clearWatch", "call_clearWatch", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getCurrentPosition",
            "watchPosition",
            "clearWatch",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
            _internal: ?*GeolocationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_clearWatch = &call_clearWatch,
        .call_getCurrentPosition = &call_getCurrentPosition,
        .call_watchPosition = &call_watchPosition,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GeolocationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GeolocationImpl.deinit(instance);
    }

    pub fn call_getCurrentPosition(instance: *runtime.Instance, successCallback: PositionCallback, errorCallback: webidl.Opt(?PositionErrorCallback), options: webidl.Opt(PositionOptions)) anyerror!void {
        
        return try GeolocationImpl.call_getCurrentPosition(instance, successCallback, errorCallback, options);
    }

    pub fn call_clearWatch(instance: *runtime.Instance, watchId: i32) anyerror!void {
        
        return try GeolocationImpl.call_clearWatch(instance, watchId);
    }

    pub fn call_watchPosition(instance: *runtime.Instance, successCallback: PositionCallback, errorCallback: webidl.Opt(?PositionErrorCallback), options: webidl.Opt(PositionOptions)) anyerror!i32 {
        
        return try GeolocationImpl.call_watchPosition(instance, successCallback, errorCallback, options);
    }

};
