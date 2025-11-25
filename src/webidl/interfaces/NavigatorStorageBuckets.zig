//! Generated from: storage-buckets.idl
//! Generated at: 2025-11-25T14:21:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorStorageBucketsImpl = @import("impls").NavigatorStorageBuckets;
const StorageBucketManager = @import("interfaces").StorageBucketManager;

pub const NavigatorStorageBuckets = struct {
    pub const Meta = struct {
        pub const name = "NavigatorStorageBuckets";
        pub const is_mixin = true;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "storageBuckets", "get_storageBuckets", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
            .{ "storageBuckets", "get_storageBuckets", null },
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
            storageBuckets: *runtime.Instance = undefined,
            cached_storageBuckets: ?*runtime.Instance = null,
            _internal: ?*NavigatorStorageBucketsImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_storageBuckets = &get_storageBuckets,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigatorStorageBucketsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorStorageBucketsImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_storageBuckets(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_storageBuckets) |cached| {
            return cached;
        }
        const value = try NavigatorStorageBucketsImpl.get_storageBuckets(instance);
        state.own.cached_storageBuckets = value;
        return value;
    }

};
