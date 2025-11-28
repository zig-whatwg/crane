//! Generated from: webmidi.idl
//! Generated at: 2025-11-28T22:33:21Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MIDIAccessImpl = @import("impls").MIDIAccess;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const MIDIOutputMap = @import("interfaces").MIDIOutputMap;
const EventListener = @import("interfaces").EventListener;
const MIDIInputMap = @import("interfaces").MIDIInputMap;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const MIDIAccess = struct {
    pub const Meta = struct {
        pub const name = "MIDIAccess";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Transferable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "inputs", "get_inputs", null },
            .{ "outputs", "get_outputs", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
            .{ "sysexEnabled", "get_sysexEnabled", null },
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
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "inputs", "get_inputs", null },
            .{ "outputs", "get_outputs", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
            .{ "sysexEnabled", "get_sysexEnabled", null },
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
            inputs: *runtime.Instance = undefined,
            outputs: *runtime.Instance = undefined,
            onstatechange: EventHandler = undefined,
            sysexEnabled: bool = undefined,
            _internal: ?*MIDIAccessImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_inputs = &get_inputs,
        .get_onstatechange = &get_onstatechange,
        .get_outputs = &get_outputs,
        .get_sysexEnabled = &get_sysexEnabled,

        .set_onstatechange = &set_onstatechange,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MIDIAccessImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MIDIAccessImpl.deinit(instance);
    }

    pub fn get_inputs(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try MIDIAccessImpl.get_inputs(instance);
    }

    pub fn get_outputs(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try MIDIAccessImpl.get_outputs(instance);
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try MIDIAccessImpl.get_onstatechange(instance);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MIDIAccessImpl.set_onstatechange(instance, value);
    }

    pub fn get_sysexEnabled(instance: *runtime.Instance) anyerror!bool {
        return try MIDIAccessImpl.get_sysexEnabled(instance);
    }

};
