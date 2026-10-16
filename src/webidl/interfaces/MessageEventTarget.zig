//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MessageEventTargetImpl = @import("impls").MessageEventTarget;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventHandler = @import("typedefs").EventHandler;

pub const MessageEventTarget = struct {
    pub const Meta = struct {
        pub const name = "MessageEventTarget";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onmessage: typedefs.EventHandler = undefined,
            onmessageerror: typedefs.EventHandler = undefined,
            _internal: ?*MessageEventTargetImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MessageEventTarget")) {
            if (comptime @hasDecl(impls.MessageEventTarget, "installHooks")) impls.MessageEventTarget.installHooks();
        }
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MessageEventTargetImpl, "get_onmessage")) return try MessageEventTargetImpl.get_onmessage(instance);
        return event_handlers.value(EventHandler, instance, "onmessage");
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MessageEventTargetImpl, "set_onmessage")) return try MessageEventTargetImpl.set_onmessage(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmessage", value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MessageEventTargetImpl, "get_onmessageerror")) return try MessageEventTargetImpl.get_onmessageerror(instance);
        return event_handlers.value(EventHandler, instance, "onmessageerror");
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MessageEventTargetImpl, "set_onmessageerror")) return try MessageEventTargetImpl.set_onmessageerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmessageerror", value);
    }
};
