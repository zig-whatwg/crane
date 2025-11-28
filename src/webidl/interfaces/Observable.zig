//! Generated from: observable.idl
//! Generated at: 2025-11-28T03:24:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ObservableImpl = @import("impls").Observable;
const Mapper = @import("callbacks").Mapper;
const Predicate = @import("callbacks").Predicate;
const VoidFunction = @import("callbacks").VoidFunction;
const Visitor = @import("callbacks").Visitor;
const ObserverUnion = @import("typedefs").ObserverUnion;
const SubscribeCallback = @import("callbacks").SubscribeCallback;
const CatchCallback = @import("callbacks").CatchCallback;
const ObservableInspectorUnion = @import("typedefs").ObservableInspectorUnion;
const SubscribeOptions = @import("dictionaries").SubscribeOptions;
const Reducer = @import("callbacks").Reducer;

pub const Observable = struct {
    pub const Meta = struct {
        pub const name = "Observable";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "subscribe", "call_subscribe", 0 },
            .{ "takeUntil", "call_takeUntil", 1 },
            .{ "map", "call_map", 1 },
            .{ "filter", "call_filter", 1 },
            .{ "take", "call_take", 1 },
            .{ "drop", "call_drop", 1 },
            .{ "flatMap", "call_flatMap", 1 },
            .{ "switchMap", "call_switchMap", 1 },
            .{ "inspect", "call_inspect", 0 },
            .{ "catch", "call_catch", 1 },
            .{ "finally", "call_finally", 1 },
            .{ "toArray", "call_toArray", 0 },
            .{ "forEach", "call_forEach", 1 },
            .{ "every", "call_every", 1 },
            .{ "first", "call_first", 0 },
            .{ "last", "call_last", 0 },
            .{ "find", "call_find", 1 },
            .{ "some", "call_some", 1 },
            .{ "reduce", "call_reduce", 1 },
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "from", "call_from", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "subscribe",
            "from",
            "takeUntil",
            "map",
            "filter",
            "take",
            "drop",
            "flatMap",
            "switchMap",
            "inspect",
            "catch",
            "finally",
            "toArray",
            "forEach",
            "every",
            "first",
            "last",
            "find",
            "some",
            "reduce",
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
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*ObservableImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_catch = &call_catch,
        .call_drop = &call_drop,
        .call_every = &call_every,
        .call_filter = &call_filter,
        .call_finally = &call_finally,
        .call_find = &call_find,
        .call_first = &call_first,
        .call_flatMap = &call_flatMap,
        .call_forEach = &call_forEach,
        .call_from = &call_from,
        .call_inspect = &call_inspect,
        .call_last = &call_last,
        .call_map = &call_map,
        .call_reduce = &call_reduce,
        .call_some = &call_some,
        .call_subscribe = &call_subscribe,
        .call_switchMap = &call_switchMap,
        .call_take = &call_take,
        .call_takeUntil = &call_takeUntil,
        .call_toArray = &call_toArray,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ObservableImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ObservableImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, callback: SubscribeCallback) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ObservableImpl.call_constructor(allocator, ctx, callback);
    }

    pub fn call_map(instance: *runtime.Instance, mapper: Mapper) anyerror!*runtime.Instance {
        
        return try ObservableImpl.call_map(instance, mapper);
    }

    pub fn call_inspect(instance: *runtime.Instance, inspectorUnion: ObservableInspectorUnion) anyerror!*runtime.Instance {
        
        return try ObservableImpl.call_inspect(instance, inspectorUnion);
    }

    pub fn call_forEach(instance: *runtime.Instance, callback: Visitor, options: SubscribeOptions) anyerror!*const anyopaque {
        
        return try ObservableImpl.call_forEach(instance, callback, options);
    }

    pub fn call_every(instance: *runtime.Instance, predicate: Predicate, options: SubscribeOptions) anyerror!*const anyopaque {
        
        return try ObservableImpl.call_every(instance, predicate, options);
    }

    pub fn call_some(instance: *runtime.Instance, predicate: Predicate, options: SubscribeOptions) anyerror!*const anyopaque {
        
        return try ObservableImpl.call_some(instance, predicate, options);
    }

    pub fn call_first(instance: *runtime.Instance, options: SubscribeOptions) anyerror!*const anyopaque {
        
        return try ObservableImpl.call_first(instance, options);
    }

    pub fn call_takeUntil(instance: *runtime.Instance, value: *const anyopaque) anyerror!*runtime.Instance {
        
        return try ObservableImpl.call_takeUntil(instance, value);
    }

    pub fn call_find(instance: *runtime.Instance, predicate: Predicate, options: SubscribeOptions) anyerror!*const anyopaque {
        
        return try ObservableImpl.call_find(instance, predicate, options);
    }

    pub fn call_last(instance: *runtime.Instance, options: SubscribeOptions) anyerror!*const anyopaque {
        
        return try ObservableImpl.call_last(instance, options);
    }

    pub fn call_filter(instance: *runtime.Instance, predicate: Predicate) anyerror!*runtime.Instance {
        
        return try ObservableImpl.call_filter(instance, predicate);
    }

    pub fn call_switchMap(instance: *runtime.Instance, mapper: Mapper) anyerror!*runtime.Instance {
        
        return try ObservableImpl.call_switchMap(instance, mapper);
    }

    pub fn call_finally(instance: *runtime.Instance, callback: VoidFunction) anyerror!*runtime.Instance {
        
        return try ObservableImpl.call_finally(instance, callback);
    }

    pub fn call_take(instance: *runtime.Instance, amount: u64) anyerror!*runtime.Instance {
        
        return try ObservableImpl.call_take(instance, amount);
    }

    pub fn call_toArray(instance: *runtime.Instance, options: SubscribeOptions) anyerror!*const anyopaque {
        
        return try ObservableImpl.call_toArray(instance, options);
    }

    pub fn call_reduce(instance: *runtime.Instance, reducer: Reducer, initialValue: *const anyopaque, options: SubscribeOptions) anyerror!*const anyopaque {
        
        return try ObservableImpl.call_reduce(instance, reducer, initialValue, options);
    }

    pub fn call_drop(instance: *runtime.Instance, amount: u64) anyerror!*runtime.Instance {
        
        return try ObservableImpl.call_drop(instance, amount);
    }

    pub fn call_flatMap(instance: *runtime.Instance, mapper: Mapper) anyerror!*runtime.Instance {
        
        return try ObservableImpl.call_flatMap(instance, mapper);
    }

    pub fn call_from(instance: *runtime.Instance, value: *const anyopaque) anyerror!*runtime.Instance {
        
        return try ObservableImpl.call_from(instance, value);
    }

    pub fn call_catch(instance: *runtime.Instance, callback: CatchCallback) anyerror!*runtime.Instance {
        
        return try ObservableImpl.call_catch(instance, callback);
    }

    pub fn call_subscribe(instance: *runtime.Instance, observer: ObserverUnion, options: SubscribeOptions) anyerror!void {
        
        return try ObservableImpl.call_subscribe(instance, observer, options);
    }

};
