//! Generated from: shared-storage.idl
//! Generated at: 2025-11-28T18:57:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SharedStorageWorkletNavigatorImpl = @import("impls").SharedStorageWorkletNavigator;
const mixins = @import("mixins");
const NavigatorLocks = @import("interfaces").NavigatorLocks;
const LockManager = @import("interfaces").LockManager;

pub const SharedStorageWorkletNavigator = struct {
    pub const Meta = struct {
        pub const name = "SharedStorageWorkletNavigator";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{
            NavigatorLocks,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "SharedStorageWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .SharedStorageWorklet = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "locks", "get_locks", null },
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
            .{ "locks", "get_locks", null },
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
            locks: *runtime.Instance = undefined,
            _internal: ?*SharedStorageWorkletNavigatorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_locks = &get_locks,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SharedStorageWorkletNavigatorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SharedStorageWorkletNavigatorImpl.deinit(instance);
    }

    pub fn get_locks(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SharedStorageWorkletNavigatorImpl.get_locks(instance);
    }

};
