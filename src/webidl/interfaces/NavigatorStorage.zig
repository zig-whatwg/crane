//! Generated from: storage.idl
//! Generated at: 2025-11-29T05:01:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorStorageImpl = @import("impls").NavigatorStorage;
const mixins = @import("mixins");
const StorageManager = @import("interfaces").StorageManager;

pub const NavigatorStorage = struct {
    pub const Meta = struct {
        pub const name = "NavigatorStorage";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "storage", "get_storage", null },
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
            .{ "storage", "get_storage", null },
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
            storage: *runtime.Instance = undefined,
            cached_storage: ?*runtime.Instance = null,
            _internal: ?*NavigatorStorageImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_storage = &get_storage,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigatorStorageImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorStorageImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_storage(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_storage) |cached| {
            return cached;
        }
        const value = try NavigatorStorageImpl.get_storage(instance);
        state.own.cached_storage = value;
        return value;
    }

};
