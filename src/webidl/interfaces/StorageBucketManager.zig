//! Generated from: storage-buckets.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const StorageBucketManagerImpl = @import("impls").StorageBucketManager;
const mixins = @import("mixins");
const StorageBucketOptions = @import("dictionaries").StorageBucketOptions;
const StorageBucket = @import("interfaces").StorageBucket;
const DOMString = @import("typedefs").DOMString;

pub const StorageBucketManager = struct {
    pub const Meta = struct {
        pub const name = "StorageBucketManager";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return StorageBucketManagerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return StorageBucketManagerImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        StorageBucketManagerImpl.deinit(instance);
    }

    pub fn call_delete(instance: *runtime.Instance, name: DOMString) anyerror!runtime.JSValue {
        
        return try StorageBucketManagerImpl.call_delete(instance, name);
    }

    pub fn call_keys(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try StorageBucketManagerImpl.call_keys(instance);
    }

    pub fn call_open(instance: *runtime.Instance, name: DOMString, options: webidl.Opt(StorageBucketOptions)) anyerror!runtime.JSValue {
        
        return try StorageBucketManagerImpl.call_open(instance, name, options);
    }

};
