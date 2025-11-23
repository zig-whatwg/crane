//! Generated from: html.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StorageEventImpl = @import("impls").StorageEvent;
const Event = @import("interfaces").Event;
const Storage = @import("interfaces").Storage;
const EventTarget = @import("interfaces").EventTarget;
const StorageEventInit = @import("dictionaries").StorageEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const StorageEvent = struct {
    pub const Meta = struct {
        pub const name = "StorageEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "key", "get_key", null },
            .{ "oldValue", "get_oldValue", null },
            .{ "newValue", "get_newValue", null },
            .{ "url", "get_url", null },
            .{ "storageArea", "get_storageArea", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "initStorageEvent", "call_initStorageEvent", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "initStorageEvent",
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
            .{ "key", "get_key", null },
            .{ "oldValue", "get_oldValue", null },
            .{ "newValue", "get_newValue", null },
            .{ "url", "get_url", null },
            .{ "storageArea", "get_storageArea", null },
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
            key: ?runtime.DOMString = null,
            oldValue: ?runtime.DOMString = null,
            newValue: ?runtime.DOMString = null,
            url: runtime.USVString = undefined,
            storageArea: ?*runtime.Instance = null,
            _internal: ?*StorageEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_key = &get_key,
        .get_newValue = &get_newValue,
        .get_oldValue = &get_oldValue,
        .get_storageArea = &get_storageArea,
        .get_url = &get_url,

        .call_initStorageEvent = &call_initStorageEvent,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return StorageEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        StorageEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: StorageEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try StorageEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_key(instance: *runtime.Instance) anyerror!DOMString {
        return try StorageEventImpl.get_key(instance);
    }

    pub fn get_oldValue(instance: *runtime.Instance) anyerror!DOMString {
        return try StorageEventImpl.get_oldValue(instance);
    }

    pub fn get_newValue(instance: *runtime.Instance) anyerror!DOMString {
        return try StorageEventImpl.get_newValue(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try StorageEventImpl.get_url(instance);
    }

    pub fn get_storageArea(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try StorageEventImpl.get_storageArea(instance);
    }

    pub fn call_initStorageEvent(instance: *runtime.Instance, @"type": DOMString, bubbles: bool, cancelable: bool, key: DOMString, oldValue: DOMString, newValue: DOMString, url: runtime.USVString, storageArea: *runtime.Instance) anyerror!void {
        
        return try StorageEventImpl.call_initStorageEvent(instance, @"type", bubbles, cancelable, key, oldValue, newValue, url, storageArea);
    }

};
