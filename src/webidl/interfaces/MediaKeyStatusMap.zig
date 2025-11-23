//! Generated from: encrypted-media.idl
//! Generated at: 2025-11-23T19:47:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaKeyStatusMapImpl = @import("impls").MediaKeyStatusMap;
const MediaKeyStatus = @import("enums").MediaKeyStatus;
const BufferSource = @import("typedefs").BufferSource;

pub const MediaKeyStatusMap = struct {
    pub const Meta = struct {
        pub const name = "MediaKeyStatusMap";
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
            .{ "size", "get_size", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "has", "call_has", 1 },
            .{ "get", "call_get", 1 },
            .{ "forEach", "call_forEach", 1 },
            .{ "forEach", "call_forEach", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "has",
            "get",
            "forEach",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "size", "get_size", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
        
        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "BufferSource",
            .key_type = "MediaKeyStatus",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            size: u32 = undefined,
            _internal: ?*MediaKeyStatusMapImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_size = &get_size,

        .call_forEach = &call_forEach,
        .call_get = &call_get,
        .call_has = &call_has,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaKeyStatusMapImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaKeyStatusMapImpl.deinit(instance);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
        return try MediaKeyStatusMapImpl.get_size(instance);
    }

    pub fn call_has(instance: *runtime.Instance, keyId: BufferSource) anyerror!bool {
        
        return try MediaKeyStatusMapImpl.call_has(instance, keyId);
    }

    pub fn call_get(instance: *runtime.Instance, keyId: BufferSource) anyerror!*const anyopaque {
        
        return try MediaKeyStatusMapImpl.call_get(instance, keyId);
    }

    pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) anyerror!void {
        
        return try MediaKeyStatusMapImpl.call_forEach(instance, callback);
    }

};
