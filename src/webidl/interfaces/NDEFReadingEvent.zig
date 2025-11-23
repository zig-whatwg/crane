//! Generated from: web-nfc.idl
//! Generated at: 2025-11-23T19:17:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NDEFReadingEventImpl = @import("impls").NDEFReadingEvent;
const Event = @import("interfaces").Event;
const EventTarget = @import("interfaces").EventTarget;
const NDEFReadingEventInit = @import("dictionaries").NDEFReadingEventInit;
const NDEFMessage = @import("interfaces").NDEFMessage;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const NDEFReadingEvent = struct {
    pub const Meta = struct {
        pub const name = "NDEFReadingEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "serialNumber", "get_serialNumber", null },
            .{ "message", "get_message", null },
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
            .{ "serialNumber", "get_serialNumber", null },
            .{ "message", "get_message", null },
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
            serialNumber: runtime.DOMString = undefined,
            message: NDEFMessage = undefined,
            cached_message: ?NDEFMessage = null,
            _internal: ?*NDEFReadingEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_message = &get_message,
        .get_serialNumber = &get_serialNumber,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NDEFReadingEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NDEFReadingEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, readingEventInitDict: NDEFReadingEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try NDEFReadingEventImpl.call_constructor(allocator, ctx, @"type", readingEventInitDict);
    }

    pub fn get_serialNumber(instance: *runtime.Instance) anyerror!DOMString {
        return try NDEFReadingEventImpl.get_serialNumber(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_message(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_message) |cached| {
            return cached;
        }
        const value = try NDEFReadingEventImpl.get_message(instance);
        state.own.cached_message = value;
        return value;
    }

};
