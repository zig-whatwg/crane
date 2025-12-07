//! Generated from: IndexedDB.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IDBIndexImpl = @import("impls").IDBIndex;
const mixins = @import("mixins");
const IDBRequest = @import("interfaces").IDBRequest;
const IDBGetAllOptions = @import("dictionaries").IDBGetAllOptions;
const IDBCursorDirection = @import("enums").IDBCursorDirection;
const DOMString = @import("typedefs").DOMString;
const IDBObjectStore = @import("interfaces").IDBObjectStore;

pub const IDBIndex = struct {
    pub const Meta = struct {
        pub const name = "IDBIndex";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "name", "get_name", "set_name" },
            .{ "objectStore", "get_objectStore", null },
            .{ "keyPath", "get_keyPath", null },
            .{ "multiEntry", "get_multiEntry", null },
            .{ "unique", "get_unique", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "get", "call_get", 1 },
            .{ "getKey", "call_getKey", 1 },
            .{ "getAll", "call_getAll", 0 },
            .{ "getAllKeys", "call_getAllKeys", 0 },
            .{ "getAllRecords", "call_getAllRecords", 0 },
            .{ "count", "call_count", 0 },
            .{ "openCursor", "call_openCursor", 0 },
            .{ "openKeyCursor", "call_openKeyCursor", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "get",
            "getKey",
            "getAll",
            "getAllKeys",
            "getAllRecords",
            "count",
            "openCursor",
            "openKeyCursor",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", "set_name" },
            .{ "objectStore", "get_objectStore", null },
            .{ "keyPath", "get_keyPath", null },
            .{ "multiEntry", "get_multiEntry", null },
            .{ "unique", "get_unique", null },
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
            name: runtime.DOMString = undefined,
            objectStore: *runtime.Instance = undefined,
            keyPath: runtime.JSValue = undefined,
            multiEntry: bool = undefined,
            unique: bool = undefined,
            cached_objectStore: ?*runtime.Instance = null,
            _internal: ?*IDBIndexImpl.InternalState = null,
        },
    );

    const delegates = .{

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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IDBIndexImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBIndexImpl.deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try IDBIndexImpl.get_name(instance);
    }

    pub fn set_name(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try IDBIndexImpl.set_name(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_objectStore(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_objectStore) |cached| {
            return cached;
        }
        const value = try IDBIndexImpl.get_objectStore(instance);
        state.own.cached_objectStore = value;
        return value;
    }

    pub fn get_keyPath(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IDBIndexImpl.get_keyPath(instance);
    }

    pub fn get_multiEntry(instance: *runtime.Instance) anyerror!bool {
        return try IDBIndexImpl.get_multiEntry(instance);
    }

    pub fn get_unique(instance: *runtime.Instance) anyerror!bool {
        return try IDBIndexImpl.get_unique(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getAll(instance: *runtime.Instance, queryOrOptions: webidl.Opt(runtime.JSValue), count: webidl.Opt(u32)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        // [EnforceRange] on count
        if (!runtime.isInRange(u32, count)) return error.TypeError;
        
        return try IDBIndexImpl.call_getAll(instance, queryOrOptions, count);
    }

    /// Extended attributes: [NewObject]
    pub fn call_openKeyCursor(instance: *runtime.Instance, query: webidl.Opt(runtime.JSValue), direction: webidl.Opt(IDBCursorDirection)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBIndexImpl.call_openKeyCursor(instance, query, direction);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getAllRecords(instance: *runtime.Instance, options: webidl.Opt(IDBGetAllOptions)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBIndexImpl.call_getAllRecords(instance, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_count(instance: *runtime.Instance, query: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBIndexImpl.call_count(instance, query);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getKey(instance: *runtime.Instance, query: runtime.JSValue) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBIndexImpl.call_getKey(instance, query);
    }

    /// Extended attributes: [NewObject]
    pub fn call_get(instance: *runtime.Instance, query: runtime.JSValue) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBIndexImpl.call_get(instance, query);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getAllKeys(instance: *runtime.Instance, queryOrOptions: webidl.Opt(runtime.JSValue), count: webidl.Opt(u32)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        // [EnforceRange] on count
        if (!runtime.isInRange(u32, count)) return error.TypeError;
        
        return try IDBIndexImpl.call_getAllKeys(instance, queryOrOptions, count);
    }

    /// Extended attributes: [NewObject]
    pub fn call_openCursor(instance: *runtime.Instance, query: webidl.Opt(runtime.JSValue), direction: webidl.Opt(IDBCursorDirection)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBIndexImpl.call_openCursor(instance, query, direction);
    }

};
