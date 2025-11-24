//! Generated from: encrypted-media.idl
//! Generated at: 2025-11-24T18:47:07Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaKeySystemAccessImpl = @import("impls").MediaKeySystemAccess;
const MediaKeySystemConfiguration = @import("dictionaries").MediaKeySystemConfiguration;
const DOMString = @import("typedefs").DOMString;
const MediaKeys = @import("interfaces").MediaKeys;

pub const MediaKeySystemAccess = struct {
    pub const Meta = struct {
        pub const name = "MediaKeySystemAccess";
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
            .{ "keySystem", "get_keySystem", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getConfiguration", "call_getConfiguration", 0 },
            .{ "createMediaKeys", "call_createMediaKeys", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getConfiguration",
            "createMediaKeys",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "keySystem", "get_keySystem", null },
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
            keySystem: runtime.DOMString = undefined,
            _internal: ?*MediaKeySystemAccessImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_keySystem = &get_keySystem,

        .call_createMediaKeys = &call_createMediaKeys,
        .call_getConfiguration = &call_getConfiguration,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaKeySystemAccessImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaKeySystemAccessImpl.deinit(instance);
    }

    pub fn get_keySystem(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaKeySystemAccessImpl.get_keySystem(instance);
    }

    pub fn call_getConfiguration(instance: *runtime.Instance) anyerror!MediaKeySystemConfiguration {
        return try MediaKeySystemAccessImpl.call_getConfiguration(instance);
    }

    pub fn call_createMediaKeys(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try MediaKeySystemAccessImpl.call_createMediaKeys(instance);
    }

};
