//! Generated from: window-controls-overlay.idl
//! Generated at: 2025-11-23T19:57:36Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WindowControlsOverlayGeometryChangeEventImpl = @import("impls").WindowControlsOverlayGeometryChangeEvent;
const Event = @import("interfaces").Event;
const DOMRect = @import("interfaces").DOMRect;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const WindowControlsOverlayGeometryChangeEventInit = @import("dictionaries").WindowControlsOverlayGeometryChangeEventInit;
const DOMString = @import("typedefs").DOMString;

pub const WindowControlsOverlayGeometryChangeEvent = struct {
    pub const Meta = struct {
        pub const name = "WindowControlsOverlayGeometryChangeEvent";
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
            .{ "titlebarAreaRect", "get_titlebarAreaRect", null },
            .{ "visible", "get_visible", null },
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
            .{ "titlebarAreaRect", "get_titlebarAreaRect", null },
            .{ "visible", "get_visible", null },
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
            titlebarAreaRect: *runtime.Instance = undefined,
            visible: bool = undefined,
            cached_titlebarAreaRect: ?*runtime.Instance = null,
            _internal: ?*WindowControlsOverlayGeometryChangeEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_titlebarAreaRect = &get_titlebarAreaRect,
        .get_visible = &get_visible,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WindowControlsOverlayGeometryChangeEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WindowControlsOverlayGeometryChangeEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: WindowControlsOverlayGeometryChangeEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try WindowControlsOverlayGeometryChangeEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    /// Extended attributes: [SameObject]
    pub fn get_titlebarAreaRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_titlebarAreaRect) |cached| {
            return cached;
        }
        const value = try WindowControlsOverlayGeometryChangeEventImpl.get_titlebarAreaRect(instance);
        state.own.cached_titlebarAreaRect = value;
        return value;
    }

    pub fn get_visible(instance: *runtime.Instance) anyerror!bool {
        return try WindowControlsOverlayGeometryChangeEventImpl.get_visible(instance);
    }

};
