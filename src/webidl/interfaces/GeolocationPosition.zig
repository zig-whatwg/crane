//! Generated from: geolocation.idl
//! Generated at: 2025-11-24T18:47:07Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GeolocationPositionImpl = @import("impls").GeolocationPosition;
const EpochTimeStamp = @import("typedefs").EpochTimeStamp;
const GeolocationCoordinates = @import("interfaces").GeolocationCoordinates;

pub const GeolocationPosition = struct {
    pub const Meta = struct {
        pub const name = "GeolocationPosition";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "coords", "get_coords", null },
            .{ "timestamp", "get_timestamp", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "coords", "get_coords", null },
            .{ "timestamp", "get_timestamp", null },
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
            coords: *runtime.Instance = undefined,
            timestamp: EpochTimeStamp = undefined,
            _internal: ?*GeolocationPositionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_coords = &get_coords,
        .get_timestamp = &get_timestamp,

        .call_toJSON = &call_toJSON,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GeolocationPositionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GeolocationPositionImpl.deinit(instance);
    }

    pub fn get_coords(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try GeolocationPositionImpl.get_coords(instance);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!EpochTimeStamp {
        return try GeolocationPositionImpl.get_timestamp(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try GeolocationPositionImpl.call_toJSON(instance);
    }

};
