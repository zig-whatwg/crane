//! Generated from: IndexedDB.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IDBCursorImpl = @import("impls").IDBCursor;
const mixins = @import("mixins");
const IDBRequest = @import("interfaces").IDBRequest;
const IDBIndex = @import("interfaces").IDBIndex;
const IDBCursorDirection = @import("enums").IDBCursorDirection;
const IDBObjectStore = @import("interfaces").IDBObjectStore;

pub const IDBCursor = struct {
    pub const Meta = struct {
        pub const name = "IDBCursor";
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
            .{ "source", "get_source", null },
            .{ "direction", "get_direction", null },
            .{ "key", "get_key", null },
            .{ "primaryKey", "get_primaryKey", null },
            .{ "request", "get_request", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "advance", "call_advance", 1 },
            .{ "continue", "call_continue", 0 },
            .{ "continuePrimaryKey", "call_continuePrimaryKey", 2 },
            .{ "update", "call_update", 1 },
            .{ "delete", "call_delete", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "advance",
            "continue",
            "continuePrimaryKey",
            "update",
            "delete",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "source", "get_source", null },
            .{ "direction", "get_direction", null },
            .{ "key", "get_key", null },
            .{ "primaryKey", "get_primaryKey", null },
            .{ "request", "get_request", null },
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
            source: union(enum) {
                IDBObjectStore: IDBObjectStore,
                IDBIndex: IDBIndex,
            } = undefined,
            direction: IDBCursorDirection = undefined,
            key: runtime.JSValue = undefined,
            primaryKey: runtime.JSValue = undefined,
            request: *runtime.Instance = undefined,
            cached_request: ?*runtime.Instance = null,
            _internal: ?*IDBCursorImpl.InternalState = null,
        },
    );

    const delegates = .{

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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IDBCursorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return IDBCursorImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBCursorImpl.deinit(instance);
    }

    pub fn get_source(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IDBCursorImpl.get_source(instance);
    }

    pub fn get_direction(instance: *runtime.Instance) anyerror!IDBCursorDirection {
        return try IDBCursorImpl.get_direction(instance);
    }

    pub fn get_key(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IDBCursorImpl.get_key(instance);
    }

    pub fn get_primaryKey(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IDBCursorImpl.get_primaryKey(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_request(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_request) |cached| {
            return cached;
        }
        const value = try IDBCursorImpl.get_request(instance);
        state.own.cached_request = value;
        return value;
    }

    pub fn call_advance(instance: *runtime.Instance, count: u32) anyerror!void {
        // [EnforceRange] on count
        if (!runtime.isInRange(u32, count)) return error.TypeError;
        
        return try IDBCursorImpl.call_advance(instance, count);
    }

    pub fn call_continue(instance: *runtime.Instance, key: webidl.Opt(runtime.JSValue)) anyerror!void {
        
        return try IDBCursorImpl.call_continue(instance, key);
    }

    /// Extended attributes: [NewObject]
    pub fn call_delete(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try IDBCursorImpl.call_delete(instance);
    }

    pub fn call_continuePrimaryKey(instance: *runtime.Instance, key: runtime.JSValue, primaryKey: runtime.JSValue) anyerror!void {
        
        return try IDBCursorImpl.call_continuePrimaryKey(instance, key, primaryKey);
    }

    /// Extended attributes: [NewObject]
    pub fn call_update(instance: *runtime.Instance, value: runtime.JSValue) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBCursorImpl.call_update(instance, value);
    }

};
