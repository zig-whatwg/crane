//! Generated from: picture-in-picture.idl
//! Generated at: 2025-11-25T19:42:24Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PictureInPictureEventImpl = @import("impls").PictureInPictureEvent;
const Event = @import("interfaces").Event;
const PictureInPictureEventInit = @import("dictionaries").PictureInPictureEventInit;
const PictureInPictureWindow = @import("interfaces").PictureInPictureWindow;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const PictureInPictureEvent = struct {
    pub const Meta = struct {
        pub const name = "PictureInPictureEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "pictureInPictureWindow", "get_pictureInPictureWindow", null },
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
            .{ "pictureInPictureWindow", "get_pictureInPictureWindow", null },
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
            pictureInPictureWindow: *runtime.Instance = undefined,
            cached_pictureInPictureWindow: ?*runtime.Instance = null,
            _internal: ?*PictureInPictureEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_pictureInPictureWindow = &get_pictureInPictureWindow,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PictureInPictureEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PictureInPictureEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: PictureInPictureEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PictureInPictureEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    /// Extended attributes: [SameObject]
    pub fn get_pictureInPictureWindow(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_pictureInPictureWindow) |cached| {
            return cached;
        }
        const value = try PictureInPictureEventImpl.get_pictureInPictureWindow(instance);
        state.own.cached_pictureInPictureWindow = value;
        return value;
    }

};
