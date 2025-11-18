//! Generated from: observable.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ObservableImpl = @import("../impls/Observable.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        ObservableImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ObservableImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, callback: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try ObservableImpl.constructor(state, callback);
        
        return instance;
    }

    pub fn call_map(instance: *runtime.Instance, mapper: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ObservableImpl.call_map(state, mapper);
    }

    pub fn call_inspect(instance: *runtime.Instance, inspectorUnion: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ObservableImpl.call_inspect(state, inspectorUnion);
    }

    pub fn call_forEach(instance: *runtime.Instance, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ObservableImpl.call_forEach(state, callback, options);
    }

    pub fn call_every(instance: *runtime.Instance, predicate: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ObservableImpl.call_every(state, predicate, options);
    }

    pub fn call_some(instance: *runtime.Instance, predicate: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ObservableImpl.call_some(state, predicate, options);
    }

    pub fn call_first(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ObservableImpl.call_first(state, options);
    }

    pub fn call_takeUntil(instance: *runtime.Instance, value: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ObservableImpl.call_takeUntil(state, value);
    }

    pub fn call_find(instance: *runtime.Instance, predicate: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ObservableImpl.call_find(state, predicate, options);
    }

    pub fn call_last(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ObservableImpl.call_last(state, options);
    }

    pub fn call_filter(instance: *runtime.Instance, predicate: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ObservableImpl.call_filter(state, predicate);
    }

    pub fn call_switchMap(instance: *runtime.Instance, mapper: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ObservableImpl.call_switchMap(state, mapper);
    }

    pub fn call_finally(instance: *runtime.Instance, callback: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ObservableImpl.call_finally(state, callback);
    }

    pub fn call_take(instance: *runtime.Instance, amount: u64) anyopaque {
        const state = instance.getState(State);
        
        return ObservableImpl.call_take(state, amount);
    }

    pub fn call_toArray(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ObservableImpl.call_toArray(state, options);
    }

    pub fn call_reduce(instance: *runtime.Instance, reducer: anyopaque, initialValue: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ObservableImpl.call_reduce(state, reducer, initialValue, options);
    }

    pub fn call_drop(instance: *runtime.Instance, amount: u64) anyopaque {
        const state = instance.getState(State);
        
        return ObservableImpl.call_drop(state, amount);
    }

    pub fn call_flatMap(instance: *runtime.Instance, mapper: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ObservableImpl.call_flatMap(state, mapper);
    }

    pub fn call_from(instance: *runtime.Instance, value: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ObservableImpl.call_from(state, value);
    }

    pub fn call_catch(instance: *runtime.Instance, callback: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ObservableImpl.call_catch(state, callback);
    }

    pub fn call_subscribe(instance: *runtime.Instance, observer: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ObservableImpl.call_subscribe(state, observer, options);
    }

};
