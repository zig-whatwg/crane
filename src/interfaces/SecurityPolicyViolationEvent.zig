//! Generated from: CSP.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SecurityPolicyViolationEventImpl = @import("../impls/SecurityPolicyViolationEvent.zig");
const Event = @import("Event.zig");

pub const SecurityPolicyViolationEvent = struct {
    pub const Meta = struct {
        pub const name = "SecurityPolicyViolationEvent";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Properties that cannot be shadowed or deleted (configurable: false)
        pub const legacy_unforgeable_properties = .{
            "isTrusted",
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            documentURI: runtime.USVString = undefined,
            referrer: runtime.USVString = undefined,
            blockedURI: runtime.USVString = undefined,
            effectiveDirective: runtime.DOMString = undefined,
            violatedDirective: runtime.DOMString = undefined,
            originalPolicy: runtime.DOMString = undefined,
            sourceFile: runtime.USVString = undefined,
            sample: runtime.DOMString = undefined,
            disposition: SecurityPolicyViolationEventDisposition = undefined,
            statusCode: u16 = undefined,
            lineNumber: u32 = undefined,
            columnNumber: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SecurityPolicyViolationEvent, .{
        .deinit_fn = &deinit_wrapper,

        .get_AT_TARGET = &Event.get_AT_TARGET,
        .get_BUBBLING_PHASE = &Event.get_BUBBLING_PHASE,
        .get_CAPTURING_PHASE = &Event.get_CAPTURING_PHASE,
        .get_NONE = &Event.get_NONE,
        .get_blockedURI = &get_blockedURI,
        .get_bubbles = &get_bubbles,
        .get_cancelBubble = &get_cancelBubble,
        .get_cancelable = &get_cancelable,
        .get_columnNumber = &get_columnNumber,
        .get_composed = &get_composed,
        .get_currentTarget = &get_currentTarget,
        .get_defaultPrevented = &get_defaultPrevented,
        .get_disposition = &get_disposition,
        .get_documentURI = &get_documentURI,
        .get_effectiveDirective = &get_effectiveDirective,
        .get_eventPhase = &get_eventPhase,
        .get_isTrusted = &get_isTrusted,
        .get_lineNumber = &get_lineNumber,
        .get_originalPolicy = &get_originalPolicy,
        .get_referrer = &get_referrer,
        .get_returnValue = &get_returnValue,
        .get_sample = &get_sample,
        .get_sourceFile = &get_sourceFile,
        .get_srcElement = &get_srcElement,
        .get_statusCode = &get_statusCode,
        .get_target = &get_target,
        .get_timeStamp = &get_timeStamp,
        .get_type = &get_type,
        .get_violatedDirective = &get_violatedDirective,

        .set_cancelBubble = &set_cancelBubble,
        .set_returnValue = &set_returnValue,

        .call_composedPath = &call_composedPath,
        .call_initEvent = &call_initEvent,
        .call_preventDefault = &call_preventDefault,
        .call_stopImmediatePropagation = &call_stopImmediatePropagation,
        .call_stopPropagation = &call_stopPropagation,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        SecurityPolicyViolationEventImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SecurityPolicyViolationEventImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, type_: runtime.DOMString, eventInitDict: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try SecurityPolicyViolationEventImpl.constructor(state, type_, eventInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_type(state);
    }

    pub fn get_target(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_target(state);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_srcElement(state);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_currentTarget(state);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_eventPhase(state);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_cancelBubble(state);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        SecurityPolicyViolationEventImpl.set_cancelBubble(state, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_bubbles(state);
    }

    pub fn get_cancelable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_cancelable(state);
    }

    pub fn get_returnValue(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_returnValue(state);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        SecurityPolicyViolationEventImpl.set_returnValue(state, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_defaultPrevented(state);
    }

    pub fn get_composed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_composed(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_isTrusted(state);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_timeStamp(state);
    }

    pub fn get_documentURI(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_documentURI(state);
    }

    pub fn get_referrer(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_referrer(state);
    }

    pub fn get_blockedURI(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_blockedURI(state);
    }

    pub fn get_effectiveDirective(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_effectiveDirective(state);
    }

    pub fn get_violatedDirective(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_violatedDirective(state);
    }

    pub fn get_originalPolicy(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_originalPolicy(state);
    }

    pub fn get_sourceFile(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_sourceFile(state);
    }

    pub fn get_sample(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_sample(state);
    }

    pub fn get_disposition(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_disposition(state);
    }

    pub fn get_statusCode(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_statusCode(state);
    }

    pub fn get_lineNumber(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_lineNumber(state);
    }

    pub fn get_columnNumber(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.get_columnNumber(state);
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.call_stopImmediatePropagation(state);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: runtime.DOMString, bubbles: bool, cancelable: bool) anyopaque {
        const state = instance.getState(State);
        
        return SecurityPolicyViolationEventImpl.call_initEvent(state, type_, bubbles, cancelable);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.call_composedPath(state);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.call_stopPropagation(state);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SecurityPolicyViolationEventImpl.call_preventDefault(state);
    }

};
