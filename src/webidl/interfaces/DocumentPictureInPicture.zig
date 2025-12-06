//! Generated from: document-picture-in-picture.idl
//! Generated at: 2025-12-05T20:30:45Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DocumentPictureInPictureImpl = @import("impls").DocumentPictureInPicture;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const Window = @import("interfaces").Window;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DocumentPictureInPictureOptions = @import("dictionaries").DocumentPictureInPictureOptions;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const DocumentPictureInPicture = struct {
    pub const Meta = struct {
        pub const name = "DocumentPictureInPicture";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "window", "get_window", null },
            .{ "onenter", "get_onenter", "set_onenter" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "requestWindow", "call_requestWindow", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "requestWindow",
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
            .{ "window", "get_window", null },
            .{ "onenter", "get_onenter", "set_onenter" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            window: *runtime.Instance = undefined,
            onenter: EventHandler = undefined,
            _internal: ?*DocumentPictureInPictureImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onenter = &get_onenter,
        .get_window = &get_window,

        .set_onenter = &set_onenter,

        .call_requestWindow = &call_requestWindow,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DocumentPictureInPictureImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DocumentPictureInPictureImpl.deinit(instance);
    }

    pub fn get_window(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try DocumentPictureInPictureImpl.get_window(instance);
    }

    pub fn get_onenter(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentPictureInPictureImpl.get_onenter(instance);
    }

    pub fn set_onenter(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentPictureInPictureImpl.set_onenter(instance, value);
    }

    /// Extended attributes: [NewObject]
    pub fn call_requestWindow(instance: *runtime.Instance, options: webidl.Opt(DocumentPictureInPictureOptions)) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object

        return try DocumentPictureInPictureImpl.call_requestWindow(instance, options);
    }
};
