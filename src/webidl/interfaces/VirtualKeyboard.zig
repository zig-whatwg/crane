//! Generated from: virtual-keyboard.idl
//! Generated at: 2025-11-25T13:07:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VirtualKeyboardImpl = @import("impls").VirtualKeyboard;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMRect = @import("interfaces").DOMRect;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const VirtualKeyboard = struct {
    pub const Meta = struct {
        pub const name = "VirtualKeyboard";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "boundingRect", "get_boundingRect", null },
            .{ "overlaysContent", "get_overlaysContent", "set_overlaysContent" },
            .{ "ongeometrychange", "get_ongeometrychange", "set_ongeometrychange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "show", "call_show", 0 },
            .{ "hide", "call_hide", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "show",
            "hide",
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
            .{ "boundingRect", "get_boundingRect", null },
            .{ "overlaysContent", "get_overlaysContent", "set_overlaysContent" },
            .{ "ongeometrychange", "get_ongeometrychange", "set_ongeometrychange" },
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
            boundingRect: *runtime.Instance = undefined,
            overlaysContent: bool = undefined,
            ongeometrychange: EventHandler = undefined,
            _internal: ?*VirtualKeyboardImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_boundingRect = &get_boundingRect,
        .get_ongeometrychange = &get_ongeometrychange,
        .get_overlaysContent = &get_overlaysContent,

        .set_ongeometrychange = &set_ongeometrychange,
        .set_overlaysContent = &set_overlaysContent,

        .call_hide = &call_hide,
        .call_show = &call_show,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return VirtualKeyboardImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        VirtualKeyboardImpl.deinit(instance);
    }

    pub fn get_boundingRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try VirtualKeyboardImpl.get_boundingRect(instance);
    }

    pub fn get_overlaysContent(instance: *runtime.Instance) anyerror!bool {
        return try VirtualKeyboardImpl.get_overlaysContent(instance);
    }

    pub fn set_overlaysContent(instance: *runtime.Instance, value: bool) anyerror!void {
        try VirtualKeyboardImpl.set_overlaysContent(instance, value);
    }

    pub fn get_ongeometrychange(instance: *runtime.Instance) anyerror!EventHandler {
        return try VirtualKeyboardImpl.get_ongeometrychange(instance);
    }

    pub fn set_ongeometrychange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try VirtualKeyboardImpl.set_ongeometrychange(instance, value);
    }

    pub fn call_hide(instance: *runtime.Instance) anyerror!void {
        return try VirtualKeyboardImpl.call_hide(instance);
    }

    pub fn call_show(instance: *runtime.Instance) anyerror!void {
        return try VirtualKeyboardImpl.call_show(instance);
    }

};
