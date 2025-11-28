//! Generated from: webmidi.idl
//! Generated at: 2025-11-28T03:24:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MIDIInputImpl = @import("impls").MIDIInput;
const MIDIPort = @import("interfaces").MIDIPort;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const MIDIPortType = @import("enums").MIDIPortType;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const MIDIPortConnectionState = @import("enums").MIDIPortConnectionState;
const MIDIPortDeviceState = @import("enums").MIDIPortDeviceState;
const EventHandler = @import("typedefs").EventHandler;

pub const MIDIInput = struct {
    pub const Meta = struct {
        pub const name = "MIDIInput";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *MIDIPort;
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
            .{ "onmidimessage", "get_onmidimessage", "set_onmidimessage" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "open",
            "close",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "onmidimessage", "get_onmidimessage", "set_onmidimessage" },
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
            onmidimessage: EventHandler = undefined,
            _internal: ?*MIDIInputImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onmidimessage = &get_onmidimessage,

        .set_onmidimessage = &set_onmidimessage,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MIDIInputImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MIDIInputImpl.deinit(instance);
    }

    pub fn get_onmidimessage(instance: *runtime.Instance) anyerror!EventHandler {
        return try MIDIInputImpl.get_onmidimessage(instance);
    }

    pub fn set_onmidimessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MIDIInputImpl.set_onmidimessage(instance, value);
    }

};
