//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-23T14:26:30Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBVersionChangeEventImpl = @import("impls").IDBVersionChangeEvent;
const Event = @import("interfaces").Event;
const EventTarget = @import("interfaces").EventTarget;
const IDBVersionChangeEventInit = @import("dictionaries").IDBVersionChangeEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const IDBVersionChangeEvent = struct {
    pub const Meta = struct {
        pub const name = "IDBVersionChangeEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
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
            .{ "oldVersion", "get_oldVersion", null },
            .{ "newVersion", "get_newVersion", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "oldVersion", "get_oldVersion", null },
            .{ "newVersion", "get_newVersion", null },
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
            oldVersion: u64 = undefined,
            newVersion: ?u64 = null,
            _internal: ?*IDBVersionChangeEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_newVersion = &get_newVersion,
        .get_oldVersion = &get_oldVersion,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IDBVersionChangeEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBVersionChangeEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: IDBVersionChangeEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try IDBVersionChangeEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_oldVersion(instance: *runtime.Instance) anyerror!u64 {
        return try IDBVersionChangeEventImpl.get_oldVersion(instance);
    }

    pub fn get_newVersion(instance: *runtime.Instance) anyerror!u64 {
        return try IDBVersionChangeEventImpl.get_newVersion(instance);
    }

};
