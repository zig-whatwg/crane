//! Generated from: webmidi.idl
//! Generated at: 2025-11-23T16:59:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MIDIConnectionEventImpl = @import("impls").MIDIConnectionEvent;
const Event = @import("interfaces").Event;
const MIDIConnectionEventInit = @import("dictionaries").MIDIConnectionEventInit;
const EventTarget = @import("interfaces").EventTarget;
const MIDIPort = @import("interfaces").MIDIPort;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const MIDIConnectionEvent = struct {
    pub const Meta = struct {
        pub const name = "MIDIConnectionEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
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
            .{ "port", "get_port", null },
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
            .{ "port", "get_port", null },
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
            port: ?MIDIPort = null,
            _internal: ?*MIDIConnectionEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_port = &get_port,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MIDIConnectionEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MIDIConnectionEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: MIDIConnectionEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MIDIConnectionEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_port(instance: *runtime.Instance) anyerror!MIDIPort {
        return try MIDIConnectionEventImpl.get_port(instance);
    }

};
