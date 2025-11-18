//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBIndexImpl = @import("../impls/IDBIndex.zig");

pub const IDBIndex = struct {
    pub const Meta = struct {
        pub const name = "IDBIndex";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            name: runtime.DOMString = undefined,
            objectStore: IDBObjectStore = undefined,
            keyPath: anyopaque = undefined,
            multiEntry: bool = undefined,
            unique: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(IDBIndex, .{
        .deinit_fn = &deinit_wrapper,

        .get_keyPath = &get_keyPath,
        .get_multiEntry = &get_multiEntry,
        .get_name = &get_name,
        .get_objectStore = &get_objectStore,
        .get_unique = &get_unique,

        .set_name = &set_name,

        .call_count = &call_count,
        .call_get = &call_get,
        .call_getAll = &call_getAll,
        .call_getAllKeys = &call_getAllKeys,
        .call_getAllRecords = &call_getAllRecords,
        .call_getKey = &call_getKey,
        .call_openCursor = &call_openCursor,
        .call_openKeyCursor = &call_openKeyCursor,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        IDBIndexImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        IDBIndexImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return IDBIndexImpl.get_name(state);
    }

    pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        IDBIndexImpl.set_name(state, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_objectStore(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_objectStore) |cached| {
            return cached;
        }
        const value = IDBIndexImpl.get_objectStore(state);
        state.cached_objectStore = value;
        return value;
    }

    pub fn get_keyPath(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBIndexImpl.get_keyPath(state);
    }

    pub fn get_multiEntry(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return IDBIndexImpl.get_multiEntry(state);
    }

    pub fn get_unique(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return IDBIndexImpl.get_unique(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getAll(instance: *runtime.Instance, queryOrOptions: anyopaque, count: u32) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        // [EnforceRange] on count
        if (count > std.math.maxInt(u53)) return error.TypeError;
        
        return IDBIndexImpl.call_getAll(state, queryOrOptions, count);
    }

    /// Extended attributes: [NewObject]
    pub fn call_openKeyCursor(instance: *runtime.Instance, query: anyopaque, direction: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBIndexImpl.call_openKeyCursor(state, query, direction);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getAllRecords(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBIndexImpl.call_getAllRecords(state, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_count(instance: *runtime.Instance, query: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBIndexImpl.call_count(state, query);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getKey(instance: *runtime.Instance, query: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBIndexImpl.call_getKey(state, query);
    }

    /// Extended attributes: [NewObject]
    pub fn call_get(instance: *runtime.Instance, query: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBIndexImpl.call_get(state, query);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getAllKeys(instance: *runtime.Instance, queryOrOptions: anyopaque, count: u32) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        // [EnforceRange] on count
        if (count > std.math.maxInt(u53)) return error.TypeError;
        
        return IDBIndexImpl.call_getAllKeys(state, queryOrOptions, count);
    }

    /// Extended attributes: [NewObject]
    pub fn call_openCursor(instance: *runtime.Instance, query: anyopaque, direction: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBIndexImpl.call_openCursor(state, query, direction);
    }

};
