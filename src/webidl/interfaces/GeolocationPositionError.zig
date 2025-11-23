//! Generated from: geolocation.idl
//! Generated at: 2025-11-23T16:59:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GeolocationPositionErrorImpl = @import("impls").GeolocationPositionError;
const DOMString = @import("typedefs").DOMString;

pub const GeolocationPositionError = struct {
    pub const Meta = struct {
        pub const name = "GeolocationPositionError";
        pub const is_mixin = false;
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
            .{ "code", "get_code", null },
            .{ "message", "get_message", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "PERMISSION_DENIED", "get_PERMISSION_DENIED" },
            .{ "POSITION_UNAVAILABLE", "get_POSITION_UNAVAILABLE" },
            .{ "TIMEOUT", "get_TIMEOUT" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "code", "get_code", null },
            .{ "message", "get_message", null },
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
            code: u16 = undefined,
            message: runtime.DOMString = undefined,
            _internal: ?*GeolocationPositionErrorImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short PERMISSION_DENIED = 1;
    pub fn get_PERMISSION_DENIED() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short POSITION_UNAVAILABLE = 2;
    pub fn get_POSITION_UNAVAILABLE() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short TIMEOUT = 3;
    pub fn get_TIMEOUT() u16 {
        return 3;
    }

    const delegates = .{

        .get_PERMISSION_DENIED = &get_PERMISSION_DENIED,
        .get_POSITION_UNAVAILABLE = &get_POSITION_UNAVAILABLE,
        .get_TIMEOUT = &get_TIMEOUT,
        .get_code = &get_code,
        .get_message = &get_message,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GeolocationPositionErrorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GeolocationPositionErrorImpl.deinit(instance);
    }

    pub fn get_code(instance: *runtime.Instance) anyerror!u16 {
        return try GeolocationPositionErrorImpl.get_code(instance);
    }

    pub fn get_message(instance: *runtime.Instance) anyerror!DOMString {
        return try GeolocationPositionErrorImpl.get_message(instance);
    }

};
