//! Generated from: css-font-loading.idl
//! Generated at: 2025-12-05T20:30:47Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FontFaceSetImpl = @import("impls").FontFaceSet;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const CSSOMString = @import("typedefs").CSSOMString;
const FontFace = @import("interfaces").FontFace;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const FontFaceSetLoadStatus = @import("enums").FontFaceSetLoadStatus;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const FontFaceSet = struct {
    pub const Meta = struct {
        pub const name = "FontFaceSet";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onloading", "get_onloading", "set_onloading" },
            .{ "onloadingdone", "get_onloadingdone", "set_onloadingdone" },
            .{ "onloadingerror", "get_onloadingerror", "set_onloadingerror" },
            .{ "ready", "get_ready", null },
            .{ "status", "get_status", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "add", "call_add", 1 },
            .{ "delete", "call_delete", 1 },
            .{ "clear", "call_clear", 0 },
            .{ "load", "call_load", 1 },
            .{ "check", "call_check", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "add",
            "delete",
            "clear",
            "load",
            "check",
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
            .{ "onloading", "get_onloading", "set_onloading" },
            .{ "onloadingdone", "get_onloadingdone", "set_onloadingdone" },
            .{ "onloadingerror", "get_onloadingerror", "set_onloadingerror" },
            .{ "ready", "get_ready", null },
            .{ "status", "get_status", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onloading: EventHandler = undefined,
            onloadingdone: EventHandler = undefined,
            onloadingerror: EventHandler = undefined,
            ready: runtime.Promise(FontFaceSet) = undefined,
            status: FontFaceSetLoadStatus = undefined,
            _internal: ?*FontFaceSetImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    const delegates = .{
        .get_onloading = &get_onloading,
        .get_onloadingdone = &get_onloadingdone,
        .get_onloadingerror = &get_onloadingerror,
        .get_ready = &get_ready,
        .get_status = &get_status,

        .set_onloading = &set_onloading,
        .set_onloadingdone = &set_onloadingdone,
        .set_onloadingerror = &set_onloadingerror,

        .call_add = &call_add,
        .call_check = &call_check,
        .call_clear = &call_clear,
        .call_delete = &call_delete,
        .call_load = &call_load,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FontFaceSetImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FontFaceSetImpl.deinit(instance);
    }

    pub fn get_onloading(instance: *runtime.Instance) anyerror!EventHandler {
        return try FontFaceSetImpl.get_onloading(instance);
    }

    pub fn set_onloading(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try FontFaceSetImpl.set_onloading(instance, value);
    }

    pub fn get_onloadingdone(instance: *runtime.Instance) anyerror!EventHandler {
        return try FontFaceSetImpl.get_onloadingdone(instance);
    }

    pub fn set_onloadingdone(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try FontFaceSetImpl.set_onloadingdone(instance, value);
    }

    pub fn get_onloadingerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try FontFaceSetImpl.get_onloadingerror(instance);
    }

    pub fn set_onloadingerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try FontFaceSetImpl.set_onloadingerror(instance, value);
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try FontFaceSetImpl.get_ready(instance);
    }

    pub fn get_status(instance: *runtime.Instance) anyerror!FontFaceSetLoadStatus {
        return try FontFaceSetImpl.get_status(instance);
    }

    pub fn call_delete(instance: *runtime.Instance, font: *runtime.Instance) anyerror!bool {
        return try FontFaceSetImpl.call_delete(instance, font);
    }

    pub fn call_add(instance: *runtime.Instance, font: *runtime.Instance) anyerror!*runtime.Instance {
        return try FontFaceSetImpl.call_add(instance, font);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try FontFaceSetImpl.call_clear(instance);
    }

    pub fn call_load(instance: *runtime.Instance, font: CSSOMString, text: webidl.Opt(CSSOMString)) anyerror!*const anyopaque {
        return try FontFaceSetImpl.call_load(instance, font, text);
    }

    pub fn call_check(instance: *runtime.Instance, font: CSSOMString, text: webidl.Opt(CSSOMString)) anyerror!bool {
        return try FontFaceSetImpl.call_check(instance, font, text);
    }
};
