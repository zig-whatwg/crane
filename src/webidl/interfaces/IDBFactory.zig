//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-29T02:15:46Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IDBFactoryImpl = @import("impls").IDBFactory;
const mixins = @import("mixins");
const IDBOpenDBRequest = @import("interfaces").IDBOpenDBRequest;
const DOMString = @import("typedefs").DOMString;

pub const IDBFactory = struct {
    pub const Meta = struct {
        pub const name = "IDBFactory";
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "open", "call_open", 1 },
            .{ "deleteDatabase", "call_deleteDatabase", 1 },
            .{ "databases", "call_databases", 0 },
            .{ "cmp", "call_cmp", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "open",
            "deleteDatabase",
            "databases",
            "cmp",
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
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*IDBFactoryImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_cmp = &call_cmp,
        .call_databases = &call_databases,
        .call_deleteDatabase = &call_deleteDatabase,
        .call_open = &call_open,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IDBFactoryImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBFactoryImpl.deinit(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_open(instance: *runtime.Instance, name: DOMString, version: webidl.Opt(u64)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        // [EnforceRange] on version
        if (!runtime.isInRange(u64, version)) return error.TypeError;
        
        return try IDBFactoryImpl.call_open(instance, name, version);
    }

    pub fn call_databases(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try IDBFactoryImpl.call_databases(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_deleteDatabase(instance: *runtime.Instance, name: DOMString) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBFactoryImpl.call_deleteDatabase(instance, name);
    }

    pub fn call_cmp(instance: *runtime.Instance, first: *const anyopaque, second: *const anyopaque) anyerror!i16 {
        
        return try IDBFactoryImpl.call_cmp(instance, first, second);
    }

};
