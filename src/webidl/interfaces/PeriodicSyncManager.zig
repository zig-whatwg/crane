//! Generated from: periodic-background-sync.idl
//! Generated at: 2025-11-24T18:47:07Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PeriodicSyncManagerImpl = @import("impls").PeriodicSyncManager;
const BackgroundSyncOptions = @import("dictionaries").BackgroundSyncOptions;
const DOMString = @import("typedefs").DOMString;

pub const PeriodicSyncManager = struct {
    pub const Meta = struct {
        pub const name = "PeriodicSyncManager";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "register", "call_register", 1 },
            .{ "getTags", "call_getTags", 0 },
            .{ "unregister", "call_unregister", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "register",
            "getTags",
            "unregister",
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
        struct {},
    );

    const delegates = .{

        .call_getTags = &call_getTags,
        .call_register = &call_register,
        .call_unregister = &call_unregister,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PeriodicSyncManagerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PeriodicSyncManagerImpl.deinit(instance);
    }

    pub fn call_getTags(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PeriodicSyncManagerImpl.call_getTags(instance);
    }

    pub fn call_unregister(instance: *runtime.Instance, tag: DOMString) anyerror!*const anyopaque {
        
        return try PeriodicSyncManagerImpl.call_unregister(instance, tag);
    }

    pub fn call_register(instance: *runtime.Instance, tag: DOMString, options: BackgroundSyncOptions) anyerror!*const anyopaque {
        
        return try PeriodicSyncManagerImpl.call_register(instance, tag, options);
    }

};
