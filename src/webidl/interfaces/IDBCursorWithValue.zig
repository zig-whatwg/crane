//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBCursorWithValueImpl = @import("impls").IDBCursorWithValue;
const IDBCursor = @import("interfaces").IDBCursor;

pub const IDBCursorWithValue = struct {
    pub const Meta = struct {
        pub const name = "IDBCursorWithValue";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *IDBCursor;
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
            value: anyopaque = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(IDBCursorWithValue, .{
        .deinit_fn = &deinit_wrapper,

        .get_direction = &get_direction,
        .get_key = &get_key,
        .get_primaryKey = &get_primaryKey,
        .get_request = &get_request,
        .get_source = &get_source,
        .get_value = &get_value,

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
        
        // Initialize the instance (Impl receives full instance)
        IDBCursorWithValueImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBCursorWithValueImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_source(instance: *runtime.Instance) anyerror!anyopaque {
        return try IDBCursorWithValueImpl.get_source(instance);
    }

    pub fn get_direction(instance: *runtime.Instance) anyerror!IDBCursorDirection {
        return try IDBCursorWithValueImpl.get_direction(instance);
    }

    pub fn get_key(instance: *runtime.Instance) anyerror!anyopaque {
        return try IDBCursorWithValueImpl.get_key(instance);
    }

    pub fn get_primaryKey(instance: *runtime.Instance) anyerror!anyopaque {
        return try IDBCursorWithValueImpl.get_primaryKey(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_request(instance: *runtime.Instance) anyerror!IDBRequest {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_request) |cached| {
            return cached;
        }
        const value = try IDBCursorWithValueImpl.get_request(instance);
        state.cached_request = value;
        return value;
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!anyopaque {
        return try IDBCursorWithValueImpl.get_value(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_delete(instance: *runtime.Instance) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        return try IDBCursorWithValueImpl.call_delete(instance);
    }

    pub fn call_continue(instance: *runtime.Instance, key: anyopaque) anyerror!void {
        
        return try IDBCursorWithValueImpl.call_continue(instance, key);
    }

    pub fn call_continuePrimaryKey(instance: *runtime.Instance, key: anyopaque, primaryKey: anyopaque) anyerror!void {
        
        return try IDBCursorWithValueImpl.call_continuePrimaryKey(instance, key, primaryKey);
    }

    /// Extended attributes: [NewObject]
    pub fn call_update(instance: *runtime.Instance, value: anyopaque) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        
        return try IDBCursorWithValueImpl.call_update(instance, value);
    }

    pub fn call_advance(instance: *runtime.Instance, count: u32) anyerror!void {
        // [EnforceRange] on count
        if (!runtime.isInRange(count)) return error.TypeError;
        
        return try IDBCursorWithValueImpl.call_advance(instance, count);
    }

};
