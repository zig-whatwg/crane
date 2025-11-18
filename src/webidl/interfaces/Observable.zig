//! Generated from: observable.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ObservableImpl = @import("impls").Observable;
const Mapper = @import("callbacks").Mapper;
const Predicate = @import("callbacks").Predicate;
const VoidFunction = @import("callbacks").VoidFunction;
const Promise<any> = @import("interfaces").Promise<any>;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const Visitor = @import("callbacks").Visitor;
const ObserverUnion = @import("typedefs").ObserverUnion;
const SubscribeCallback = @import("callbacks").SubscribeCallback;
const CatchCallback = @import("callbacks").CatchCallback;
const Promise<sequence<any>> = @import("interfaces").Promise<sequence<any>>;
const ObservableInspectorUnion = @import("typedefs").ObservableInspectorUnion;
const SubscribeOptions = @import("dictionaries").SubscribeOptions;
const Promise<boolean> = @import("interfaces").Promise<boolean>;
const Reducer = @import("callbacks").Reducer;

pub const Observable = struct {
    pub const Meta = struct {
        pub const name = "Observable";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Observable, .{
        .deinit_fn = &deinit_wrapper,

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ObservableImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ObservableImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, callback: SubscribeCallback) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try ObservableImpl.constructor(instance, callback);
        
        return instance;
    }

    pub fn call_map(instance: *runtime.Instance, mapper: Mapper) anyerror!Observable {
        
        return try ObservableImpl.call_map(instance, mapper);
    }

    pub fn call_inspect(instance: *runtime.Instance, inspectorUnion: ObservableInspectorUnion) anyerror!Observable {
        
        return try ObservableImpl.call_inspect(instance, inspectorUnion);
    }

    pub fn call_forEach(instance: *runtime.Instance, callback: Visitor, options: SubscribeOptions) anyerror!anyopaque {
        
        return try ObservableImpl.call_forEach(instance, callback, options);
    }

    pub fn call_every(instance: *runtime.Instance, predicate: Predicate, options: SubscribeOptions) anyerror!anyopaque {
        
        return try ObservableImpl.call_every(instance, predicate, options);
    }

    pub fn call_some(instance: *runtime.Instance, predicate: Predicate, options: SubscribeOptions) anyerror!anyopaque {
        
        return try ObservableImpl.call_some(instance, predicate, options);
    }

    pub fn call_first(instance: *runtime.Instance, options: SubscribeOptions) anyerror!anyopaque {
        
        return try ObservableImpl.call_first(instance, options);
    }

    pub fn call_takeUntil(instance: *runtime.Instance, value: anyopaque) anyerror!Observable {
        
        return try ObservableImpl.call_takeUntil(instance, value);
    }

    pub fn call_find(instance: *runtime.Instance, predicate: Predicate, options: SubscribeOptions) anyerror!anyopaque {
        
        return try ObservableImpl.call_find(instance, predicate, options);
    }

    pub fn call_last(instance: *runtime.Instance, options: SubscribeOptions) anyerror!anyopaque {
        
        return try ObservableImpl.call_last(instance, options);
    }

    pub fn call_filter(instance: *runtime.Instance, predicate: Predicate) anyerror!Observable {
        
        return try ObservableImpl.call_filter(instance, predicate);
    }

    pub fn call_switchMap(instance: *runtime.Instance, mapper: Mapper) anyerror!Observable {
        
        return try ObservableImpl.call_switchMap(instance, mapper);
    }

    pub fn call_finally(instance: *runtime.Instance, callback: VoidFunction) anyerror!Observable {
        
        return try ObservableImpl.call_finally(instance, callback);
    }

    pub fn call_take(instance: *runtime.Instance, amount: u64) anyerror!Observable {
        
        return try ObservableImpl.call_take(instance, amount);
    }

    pub fn call_toArray(instance: *runtime.Instance, options: SubscribeOptions) anyerror!anyopaque {
        
        return try ObservableImpl.call_toArray(instance, options);
    }

    pub fn call_reduce(instance: *runtime.Instance, reducer: Reducer, initialValue: anyopaque, options: SubscribeOptions) anyerror!anyopaque {
        
        return try ObservableImpl.call_reduce(instance, reducer, initialValue, options);
    }

    pub fn call_drop(instance: *runtime.Instance, amount: u64) anyerror!Observable {
        
        return try ObservableImpl.call_drop(instance, amount);
    }

    pub fn call_flatMap(instance: *runtime.Instance, mapper: Mapper) anyerror!Observable {
        
        return try ObservableImpl.call_flatMap(instance, mapper);
    }

    pub fn call_from(instance: *runtime.Instance, value: anyopaque) anyerror!Observable {
        
        return try ObservableImpl.call_from(instance, value);
    }

    pub fn call_catch(instance: *runtime.Instance, callback: CatchCallback) anyerror!Observable {
        
        return try ObservableImpl.call_catch(instance, callback);
    }

    pub fn call_subscribe(instance: *runtime.Instance, observer: ObserverUnion, options: SubscribeOptions) anyerror!void {
        
        return try ObservableImpl.call_subscribe(instance, observer, options);
    }

};
