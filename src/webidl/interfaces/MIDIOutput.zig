//! Generated from: webmidi.idl
//! Generated at: 2025-11-23T19:57:36Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MIDIOutputImpl = @import("impls").MIDIOutput;
const MIDIPort = @import("interfaces").MIDIPort;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const EventHandler = @import("typedefs").EventHandler;
const MIDIPortType = @import("enums").MIDIPortType;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const MIDIPortConnectionState = @import("enums").MIDIPortConnectionState;
const MIDIPortDeviceState = @import("enums").MIDIPortDeviceState;
const DOMString = @import("typedefs").DOMString;

pub const MIDIOutput = struct {
    pub const Meta = struct {
        pub const name = "MIDIOutput";
        pub const is_mixin = false;
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "send", "call_send", 1 },
            .{ "clear", "call_clear", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "send",
            "clear",
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
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_clear = &call_clear,
        .call_send = &call_send,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MIDIOutputImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MIDIOutputImpl.deinit(instance);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try MIDIOutputImpl.call_clear(instance);
    }

    pub fn call_send(instance: *runtime.Instance, data: *const anyopaque, timestamp: DOMHighResTimeStamp) anyerror!void {
        
        return try MIDIOutputImpl.call_send(instance, data, timestamp);
    }

};
