//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBCursorImpl = @import("../impls/IDBCursor.zig");

pub const IDBCursor = struct {
    pub const Meta = struct {
        pub const name = "IDBCursor";
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
            source: (IDBObjectStore or IDBIndex) = undefined,
            direction: IDBCursorDirection = undefined,
            key: anyopaque = undefined,
            primaryKey: anyopaque = undefined,
            request: IDBRequest = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(IDBCursor, .{
        .deinit_fn = &deinit_wrapper,

        .get_direction = &get_direction,
        .get_key = &get_key,
        .get_primaryKey = &get_primaryKey,
        .get_request = &get_request,
        .get_source = &get_source,

        .call_advance = &call_advance,
        .call_continue = &call_continue,
        .call_continuePrimaryKey = &call_continuePrimaryKey,
        .call_delete = &call_delete,
        .call_update = &call_update,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        IDBCursorImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        IDBCursorImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_source(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBCursorImpl.get_source(state);
    }

    pub fn get_direction(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBCursorImpl.get_direction(state);
    }

    pub fn get_key(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBCursorImpl.get_key(state);
    }

    pub fn get_primaryKey(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBCursorImpl.get_primaryKey(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_request(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_request) |cached| {
            return cached;
        }
        const value = IDBCursorImpl.get_request(state);
        state.cached_request = value;
        return value;
    }

    /// Extended attributes: [NewObject]
    pub fn call_delete(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return IDBCursorImpl.call_delete(state);
    }

    pub fn call_continue(instance: *runtime.Instance, key: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return IDBCursorImpl.call_continue(state, key);
    }

    pub fn call_continuePrimaryKey(instance: *runtime.Instance, key: anyopaque, primaryKey: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return IDBCursorImpl.call_continuePrimaryKey(state, key, primaryKey);
    }

    /// Extended attributes: [NewObject]
    pub fn call_update(instance: *runtime.Instance, value: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBCursorImpl.call_update(state, value);
    }

    pub fn call_advance(instance: *runtime.Instance, count: u32) anyopaque {
        const state = instance.getState(State);
        // [EnforceRange] on count
        if (count > std.math.maxInt(u53)) return error.TypeError;
        
        return IDBCursorImpl.call_advance(state, count);
    }

};
