//! Generated from: storage-buckets.idl
//! Generated at: 2025-11-25T14:21:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StorageBucketManagerImpl = @import("impls").StorageBucketManager;
const StorageBucketOptions = @import("dictionaries").StorageBucketOptions;
const StorageBucket = @import("interfaces").StorageBucket;
const DOMString = @import("typedefs").DOMString;

pub const StorageBucketManager = struct {
    pub const Meta = struct {
        pub const name = "StorageBucketManager";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
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
            .{ "open", "call_open", 1 },
            .{ "keys", "call_keys", 0 },
            .{ "delete", "call_delete", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "open",
            "keys",
            "delete",
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
            _internal: ?*StorageBucketManagerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_delete = &call_delete,
        .call_keys = &call_keys,
        .call_open = &call_open,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return StorageBucketManagerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        StorageBucketManagerImpl.deinit(instance);
    }

    pub fn call_delete(instance: *runtime.Instance, name: DOMString) anyerror!*const anyopaque {
        
        return try StorageBucketManagerImpl.call_delete(instance, name);
    }

    pub fn call_keys(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try StorageBucketManagerImpl.call_keys(instance);
    }

    pub fn call_open(instance: *runtime.Instance, name: DOMString, options: StorageBucketOptions) anyerror!*const anyopaque {
        
        return try StorageBucketManagerImpl.call_open(instance, name, options);
    }

};
