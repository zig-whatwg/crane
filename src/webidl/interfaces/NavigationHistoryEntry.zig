//! Generated from: html.idl
//! Generated at: 2025-11-25T20:02:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigationHistoryEntryImpl = @import("impls").NavigationHistoryEntry;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const EventHandler = @import("typedefs").EventHandler;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;

pub const NavigationHistoryEntry = struct {
    pub const Meta = struct {
        pub const name = "NavigationHistoryEntry";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "url", "get_url", null },
            .{ "key", "get_key", null },
            .{ "id", "get_id", null },
            .{ "index", "get_index", null },
            .{ "sameDocument", "get_sameDocument", null },
            .{ "ondispose", "get_ondispose", "set_ondispose" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getState", "call_getState", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getState",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "url", "get_url", null },
            .{ "key", "get_key", null },
            .{ "id", "get_id", null },
            .{ "index", "get_index", null },
            .{ "sameDocument", "get_sameDocument", null },
            .{ "ondispose", "get_ondispose", "set_ondispose" },
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
            url: ?runtime.USVString = null,
            key: runtime.DOMString = undefined,
            id: runtime.DOMString = undefined,
            index: i64 = undefined,
            sameDocument: bool = undefined,
            ondispose: EventHandler = undefined,
            _internal: ?*NavigationHistoryEntryImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_id = &get_id,
        .get_index = &get_index,
        .get_key = &get_key,
        .get_ondispose = &get_ondispose,
        .get_sameDocument = &get_sameDocument,
        .get_url = &get_url,

        .set_ondispose = &set_ondispose,

        .call_getState = &call_getState,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigationHistoryEntryImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigationHistoryEntryImpl.deinit(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!?runtime.USVString {
        return try NavigationHistoryEntryImpl.get_url(instance);
    }

    pub fn get_key(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigationHistoryEntryImpl.get_key(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigationHistoryEntryImpl.get_id(instance);
    }

    pub fn get_index(instance: *runtime.Instance) anyerror!i64 {
        return try NavigationHistoryEntryImpl.get_index(instance);
    }

    pub fn get_sameDocument(instance: *runtime.Instance) anyerror!bool {
        return try NavigationHistoryEntryImpl.get_sameDocument(instance);
    }

    pub fn get_ondispose(instance: *runtime.Instance) anyerror!EventHandler {
        return try NavigationHistoryEntryImpl.get_ondispose(instance);
    }

    pub fn set_ondispose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NavigationHistoryEntryImpl.set_ondispose(instance, value);
    }

    pub fn call_getState(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NavigationHistoryEntryImpl.call_getState(instance);
    }

};
