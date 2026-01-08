//! Generated from: webmidi.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MIDIPortImpl = @import("impls").MIDIPort;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("EventTarget.zig").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const MIDIPortType = @import("enums").MIDIPortType;
const Observable = @import("Observable.zig").Observable;
const Event = @import("Event.zig").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const MIDIPortConnectionState = @import("enums").MIDIPortConnectionState;
const EventListener = @import("EventListener.zig").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const MIDIPortDeviceState = @import("enums").MIDIPortDeviceState;

pub const MIDIPort = struct {
    pub const Meta = struct {
        pub const name = "MIDIPort";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "id", "get_id", null },
            .{ "manufacturer", "get_manufacturer", null },
            .{ "name", "get_name", null },
            .{ "type", "get_type", null },
            .{ "version", "get_version", null },
            .{ "state", "get_state", null },
            .{ "connection", "get_connection", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "open", "call_open", 0 },
            .{ "close", "call_close", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "open",
            "close",
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
            .{ "id", "get_id", null },
            .{ "manufacturer", "get_manufacturer", null },
            .{ "name", "get_name", null },
            .{ "type", "get_type", null },
            .{ "version", "get_version", null },
            .{ "state", "get_state", null },
            .{ "connection", "get_connection", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
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
            id: typedefs.DOMString = undefined,
            manufacturer: ?typedefs.DOMString = null,
            name: ?typedefs.DOMString = null,
            @"type": enums.MIDIPortType = undefined,
            version: ?typedefs.DOMString = null,
            state: enums.MIDIPortDeviceState = undefined,
            connection: enums.MIDIPortConnectionState = undefined,
            onstatechange: typedefs.EventHandler = undefined,
            _internal: ?*MIDIPortImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_connection = &get_connection,
        .get_id = &get_id,
        .get_manufacturer = &get_manufacturer,
        .get_name = &get_name,
        .get_onstatechange = &get_onstatechange,
        .get_state = &get_state,
        .get_type = &get_type,
        .get_version = &get_version,

        .set_onstatechange = &set_onstatechange,

        .call_close = &call_close,
        .call_open = &call_open,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MIDIPortImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return MIDIPortImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MIDIPortImpl.deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try MIDIPortImpl.get_id(instance);
    }

    pub fn get_manufacturer(instance: *runtime.Instance) anyerror!?DOMString {
        return try MIDIPortImpl.get_manufacturer(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!?DOMString {
        return try MIDIPortImpl.get_name(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!MIDIPortType {
        return try MIDIPortImpl.get_type(instance);
    }

    pub fn get_version(instance: *runtime.Instance) anyerror!?DOMString {
        return try MIDIPortImpl.get_version(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!MIDIPortDeviceState {
        return try MIDIPortImpl.get_state(instance);
    }

    pub fn get_connection(instance: *runtime.Instance) anyerror!MIDIPortConnectionState {
        return try MIDIPortImpl.get_connection(instance);
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try MIDIPortImpl.get_onstatechange(instance);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MIDIPortImpl.set_onstatechange(instance, value);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MIDIPortImpl.call_close(instance);
    }

    pub fn call_open(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MIDIPortImpl.call_open(instance);
    }

};
