//! Generated from: dom.idl
//! Generated at: 2025-11-28T18:57:54Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const EventImpl = @import("impls").Event;
const mixins = @import("mixins");
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const EventTarget = @import("interfaces").EventTarget;
const DOMString = @import("typedefs").DOMString;

pub const Event = struct {
    pub const Meta = struct {
        pub const name = "Event";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "type", "get_type", null },
            .{ "target", "get_target", null },
            .{ "srcElement", "get_srcElement", null },
            .{ "currentTarget", "get_currentTarget", null },
            .{ "eventPhase", "get_eventPhase", null },
            .{ "cancelBubble", "get_cancelBubble", "set_cancelBubble" },
            .{ "bubbles", "get_bubbles", null },
            .{ "cancelable", "get_cancelable", null },
            .{ "returnValue", "get_returnValue", "set_returnValue" },
            .{ "defaultPrevented", "get_defaultPrevented", null },
            .{ "composed", "get_composed", null },
            .{ "isTrusted", "get_isTrusted", null },
            .{ "timeStamp", "get_timeStamp", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "composedPath", "call_composedPath", 0 },
            .{ "stopPropagation", "call_stopPropagation", 0 },
            .{ "stopImmediatePropagation", "call_stopImmediatePropagation", 0 },
            .{ "preventDefault", "call_preventDefault", 0 },
            .{ "initEvent", "call_initEvent", 1 },
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "NONE", "get_NONE" },
            .{ "CAPTURING_PHASE", "get_CAPTURING_PHASE" },
            .{ "AT_TARGET", "get_AT_TARGET" },
            .{ "BUBBLING_PHASE", "get_BUBBLING_PHASE" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "type", "get_type", null },
            .{ "target", "get_target", null },
            .{ "srcElement", "get_srcElement", null },
            .{ "currentTarget", "get_currentTarget", null },
            .{ "eventPhase", "get_eventPhase", null },
            .{ "cancelBubble", "get_cancelBubble", "set_cancelBubble" },
            .{ "bubbles", "get_bubbles", null },
            .{ "cancelable", "get_cancelable", null },
            .{ "returnValue", "get_returnValue", "set_returnValue" },
            .{ "defaultPrevented", "get_defaultPrevented", null },
            .{ "composed", "get_composed", null },
            .{ "isTrusted", "get_isTrusted", null },
            .{ "timeStamp", "get_timeStamp", null },
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
            @"type": runtime.DOMString = undefined,
            target: ?*runtime.Instance = null,
            srcElement: ?*runtime.Instance = null,
            currentTarget: ?*runtime.Instance = null,
            eventPhase: u16 = undefined,
            cancelBubble: bool = undefined,
            bubbles: bool = undefined,
            cancelable: bool = undefined,
            returnValue: bool = undefined,
            defaultPrevented: bool = undefined,
            composed: bool = undefined,
            isTrusted: bool = undefined,
            timeStamp: DOMHighResTimeStamp = undefined,
            _internal: ?*EventImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short NONE = 0;
    pub fn get_NONE() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short CAPTURING_PHASE = 1;
    pub fn get_CAPTURING_PHASE() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short AT_TARGET = 2;
    pub fn get_AT_TARGET() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short BUBBLING_PHASE = 3;
    pub fn get_BUBBLING_PHASE() u16 {
        return 3;
    }

    const delegates = .{

        .get_AT_TARGET = &get_AT_TARGET,
        .get_BUBBLING_PHASE = &get_BUBBLING_PHASE,
        .get_CAPTURING_PHASE = &get_CAPTURING_PHASE,
        .get_NONE = &get_NONE,
        .get_bubbles = &get_bubbles,
        .get_cancelBubble = &get_cancelBubble,
        .get_cancelable = &get_cancelable,
        .get_composed = &get_composed,
        .get_currentTarget = &get_currentTarget,
        .get_defaultPrevented = &get_defaultPrevented,
        .get_eventPhase = &get_eventPhase,
        .get_isTrusted = &get_isTrusted,
        .get_returnValue = &get_returnValue,
        .get_srcElement = &get_srcElement,
        .get_target = &get_target,
        .get_timeStamp = &get_timeStamp,
        .get_type = &get_type,

        .set_cancelBubble = &set_cancelBubble,
        .set_returnValue = &set_returnValue,

        .call_composedPath = &call_composedPath,
        .call_initEvent = &call_initEvent,
        .call_preventDefault = &call_preventDefault,
        .call_stopImmediatePropagation = &call_stopImmediatePropagation,
        .call_stopPropagation = &call_stopPropagation,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return EventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(EventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try EventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try EventImpl.get_type(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try EventImpl.get_target(instance);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try EventImpl.get_srcElement(instance);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try EventImpl.get_currentTarget(instance);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) anyerror!u16 {
        return try EventImpl.get_eventPhase(instance);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) anyerror!bool {
        return try EventImpl.get_cancelBubble(instance);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) anyerror!void {
        try EventImpl.set_cancelBubble(instance, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) anyerror!bool {
        return try EventImpl.get_bubbles(instance);
    }

    pub fn get_cancelable(instance: *runtime.Instance) anyerror!bool {
        return try EventImpl.get_cancelable(instance);
    }

    pub fn get_returnValue(instance: *runtime.Instance) anyerror!bool {
        return try EventImpl.get_returnValue(instance);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) anyerror!void {
        try EventImpl.set_returnValue(instance, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) anyerror!bool {
        return try EventImpl.get_defaultPrevented(instance);
    }

    pub fn get_composed(instance: *runtime.Instance) anyerror!bool {
        return try EventImpl.get_composed(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) anyerror!bool {
        return try EventImpl.get_isTrusted(instance);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try EventImpl.get_timeStamp(instance);
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyerror!void {
        return try EventImpl.call_stopImmediatePropagation(instance);
    }

    pub fn call_initEvent(instance: *runtime.Instance, @"type": DOMString, bubbles: webidl.Opt(bool), cancelable: webidl.Opt(bool)) anyerror!void {
        
        return try EventImpl.call_initEvent(instance, @"type", bubbles, cancelable);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try EventImpl.call_composedPath(instance);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyerror!void {
        return try EventImpl.call_stopPropagation(instance);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyerror!void {
        return try EventImpl.call_preventDefault(instance);
    }

};
