//! Generated from: encrypted-media.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaKeyMessageEventImpl = @import("impls").MediaKeyMessageEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Event = @import("Event.zig").Event;
const EventTarget = @import("EventTarget.zig").EventTarget;
const MediaKeyMessageType = @import("enums").MediaKeyMessageType;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const MediaKeyMessageEventInit = @import("dictionaries").MediaKeyMessageEventInit;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const MediaKeyMessageEvent = struct {
    pub const Meta = struct {
        pub const name = "MediaKeyMessageEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "messageType", "get_messageType", null },
            .{ "message", "get_message", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "messageType", "get_messageType", null },
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
            messageType: enums.MediaKeyMessageType = undefined,
            message: runtime.ArrayBuffer = undefined,
            _internal: ?*MediaKeyMessageEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_message = &get_message,
        .get_messageType = &get_messageType,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaKeyMessageEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return MediaKeyMessageEventImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaKeyMessageEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": DOMString, eventInitDict: MediaKeyMessageEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MediaKeyMessageEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    pub fn get_messageType(instance: *runtime.Instance) anyerror!MediaKeyMessageType {
        return try MediaKeyMessageEventImpl.get_messageType(instance);
    }

    pub fn get_message(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MediaKeyMessageEventImpl.get_message(instance);
    }

};
