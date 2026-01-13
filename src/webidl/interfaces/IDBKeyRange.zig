//! Generated from: IndexedDB.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IDBKeyRangeImpl = @import("impls").IDBKeyRange;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const IDBKeyRange = struct {
    pub const Meta = struct {
        pub const name = "IDBKeyRange";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "includes", "call_includes", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "only", "call_static_only", 1 },
            .{ "lowerBound", "call_static_lowerBound", 1 },
            .{ "upperBound", "call_static_upperBound", 1 },
            .{ "bound", "call_static_bound", 2 },
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            lower: runtime.JSValue = undefined,
            upper: runtime.JSValue = undefined,
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

        .call_includes = &call_includes,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IDBKeyRangeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return IDBKeyRangeImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBKeyRangeImpl.deinit(instance);
    }

    pub fn get_lower(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IDBKeyRangeImpl.get_lower(instance);
    }

    pub fn get_upper(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IDBKeyRangeImpl.get_upper(instance);
    }

    pub fn get_lowerOpen(instance: *runtime.Instance) anyerror!bool {
        return try IDBKeyRangeImpl.get_lowerOpen(instance);
    }

    pub fn get_upperOpen(instance: *runtime.Instance) anyerror!bool {
        return try IDBKeyRangeImpl.get_upperOpen(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_static_only(instance: *runtime.Instance, value: runtime.JSValue) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBKeyRangeImpl.call_static_only(instance, value);
    }

    /// Extended attributes: [NewObject]
    pub fn call_static_lowerBound(instance: *runtime.Instance, lower: runtime.JSValue, open: webidl.Opt(bool)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBKeyRangeImpl.call_static_lowerBound(instance, lower, open);
    }

    /// Extended attributes: [NewObject]
    pub fn call_static_upperBound(instance: *runtime.Instance, upper: runtime.JSValue, open: webidl.Opt(bool)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBKeyRangeImpl.call_static_upperBound(instance, upper, open);
    }

    /// Extended attributes: [NewObject]
    pub fn call_static_bound(instance: *runtime.Instance, lower: runtime.JSValue, upper: runtime.JSValue, lowerOpen: webidl.Opt(bool), upperOpen: webidl.Opt(bool)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBKeyRangeImpl.call_static_bound(instance, lower, upper, lowerOpen, upperOpen);
    }

    pub fn call_includes(instance: *runtime.Instance, key: runtime.JSValue) anyerror!bool {
        
        return try IDBKeyRangeImpl.call_includes(instance, key);
    }

};
