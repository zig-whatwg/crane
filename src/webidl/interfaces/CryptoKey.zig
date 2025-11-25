//! Generated from: webcrypto.idl
//! Generated at: 2025-11-25T20:02:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CryptoKeyImpl = @import("impls").CryptoKey;
const KeyType = @import("enums").KeyType;

pub const CryptoKey = struct {
    pub const Meta = struct {
        pub const name = "CryptoKey";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "type", "get_type", null },
            .{ "extractable", "get_extractable", null },
            .{ "algorithm", "get_algorithm", null },
            .{ "usages", "get_usages", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "type", "get_type", null },
            .{ "extractable", "get_extractable", null },
            .{ "algorithm", "get_algorithm", null },
            .{ "usages", "get_usages", null },
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
            @"type": KeyType = undefined,
            extractable: bool = undefined,
            algorithm: *const anyopaque = undefined,
            usages: *const anyopaque = undefined,
            _internal: ?*CryptoKeyImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_algorithm = &get_algorithm,
        .get_extractable = &get_extractable,
        .get_type = &get_type,
        .get_usages = &get_usages,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CryptoKeyImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CryptoKeyImpl.deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!KeyType {
        return try CryptoKeyImpl.get_type(instance);
    }

    pub fn get_extractable(instance: *runtime.Instance) anyerror!bool {
        return try CryptoKeyImpl.get_extractable(instance);
    }

    pub fn get_algorithm(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try CryptoKeyImpl.get_algorithm(instance);
    }

    pub fn get_usages(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try CryptoKeyImpl.get_usages(instance);
    }

};
