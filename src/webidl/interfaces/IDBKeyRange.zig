//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBKeyRangeImpl = @import("impls").IDBKeyRange;

pub const IDBKeyRange = struct {
    pub const Meta = struct {
        pub const name = "IDBKeyRange";
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
            .{ "lower", "get_lower", null },
            .{ "upper", "get_upper", null },
            .{ "lowerOpen", "get_lowerOpen", null },
            .{ "upperOpen", "get_upperOpen", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "only", "call_only", 1 },
            .{ "lowerBound", "call_lowerBound", 1 },
            .{ "upperBound", "call_upperBound", 1 },
            .{ "bound", "call_bound", 2 },
            .{ "includes", "call_includes", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "only",
            "lowerBound",
            "upperBound",
            "bound",
            "includes",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "lower", "get_lower", null },
            .{ "upper", "get_upper", null },
            .{ "lowerOpen", "get_lowerOpen", null },
            .{ "upperOpen", "get_upperOpen", null },
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
            lower: *const anyopaque = undefined,
            upper: *const anyopaque = undefined,
            lowerOpen: bool = undefined,
            upperOpen: bool = undefined,
            _internal: ?*IDBKeyRangeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_lower = &get_lower,
        .get_lowerOpen = &get_lowerOpen,
        .get_upper = &get_upper,
        .get_upperOpen = &get_upperOpen,

        .call_bound = &call_bound,
        .call_includes = &call_includes,
        .call_lowerBound = &call_lowerBound,
        .call_only = &call_only,
        .call_upperBound = &call_upperBound,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IDBKeyRangeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBKeyRangeImpl.deinit(instance);
    }

    pub fn get_lower(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try IDBKeyRangeImpl.get_lower(instance);
    }

    pub fn get_upper(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try IDBKeyRangeImpl.get_upper(instance);
    }

    pub fn get_lowerOpen(instance: *runtime.Instance) anyerror!bool {
        return try IDBKeyRangeImpl.get_lowerOpen(instance);
    }

    pub fn get_upperOpen(instance: *runtime.Instance) anyerror!bool {
        return try IDBKeyRangeImpl.get_upperOpen(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_only(instance: *runtime.Instance, value: *const anyopaque) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBKeyRangeImpl.call_only(instance, value);
    }

    pub fn call_includes(instance: *runtime.Instance, key: *const anyopaque) anyerror!bool {
        
        return try IDBKeyRangeImpl.call_includes(instance, key);
    }

    /// Extended attributes: [NewObject]
    pub fn call_bound(instance: *runtime.Instance, lower: *const anyopaque, upper: *const anyopaque, lowerOpen: bool, upperOpen: bool) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBKeyRangeImpl.call_bound(instance, lower, upper, lowerOpen, upperOpen);
    }

    /// Extended attributes: [NewObject]
    pub fn call_upperBound(instance: *runtime.Instance, upper: *const anyopaque, open: bool) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBKeyRangeImpl.call_upperBound(instance, upper, open);
    }

    /// Extended attributes: [NewObject]
    pub fn call_lowerBound(instance: *runtime.Instance, lower: *const anyopaque, open: bool) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBKeyRangeImpl.call_lowerBound(instance, lower, open);
    }

};
