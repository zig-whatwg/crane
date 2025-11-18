//! Generated from: CSP.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SecurityPolicyViolationEventImpl = @import("impls").SecurityPolicyViolationEvent;
const Event = @import("interfaces").Event;
const SecurityPolicyViolationEventDisposition = @import("enums").SecurityPolicyViolationEventDisposition;
const SecurityPolicyViolationEventInit = @import("dictionaries").SecurityPolicyViolationEventInit;

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
        
        // Initialize the instance (Impl receives full instance)
        SecurityPolicyViolationEventImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SecurityPolicyViolationEventImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, type_: DOMString, eventInitDict: SecurityPolicyViolationEventInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try SecurityPolicyViolationEventImpl.constructor(instance, type_, eventInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try SecurityPolicyViolationEventImpl.get_type(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!anyopaque {
        return try SecurityPolicyViolationEventImpl.get_target(instance);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try SecurityPolicyViolationEventImpl.get_srcElement(instance);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyerror!anyopaque {
        return try SecurityPolicyViolationEventImpl.get_currentTarget(instance);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) anyerror!u16 {
        return try SecurityPolicyViolationEventImpl.get_eventPhase(instance);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) anyerror!bool {
        return try SecurityPolicyViolationEventImpl.get_cancelBubble(instance);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) anyerror!void {
        try SecurityPolicyViolationEventImpl.set_cancelBubble(instance, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) anyerror!bool {
        return try SecurityPolicyViolationEventImpl.get_bubbles(instance);
    }

    pub fn get_cancelable(instance: *runtime.Instance) anyerror!bool {
        return try SecurityPolicyViolationEventImpl.get_cancelable(instance);
    }

    pub fn get_returnValue(instance: *runtime.Instance) anyerror!bool {
        return try SecurityPolicyViolationEventImpl.get_returnValue(instance);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) anyerror!void {
        try SecurityPolicyViolationEventImpl.set_returnValue(instance, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) anyerror!bool {
        return try SecurityPolicyViolationEventImpl.get_defaultPrevented(instance);
    }

    pub fn get_composed(instance: *runtime.Instance) anyerror!bool {
        return try SecurityPolicyViolationEventImpl.get_composed(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) anyerror!bool {
        return try SecurityPolicyViolationEventImpl.get_isTrusted(instance);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try SecurityPolicyViolationEventImpl.get_timeStamp(instance);
    }

    pub fn get_documentURI(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try SecurityPolicyViolationEventImpl.get_documentURI(instance);
    }

    pub fn get_referrer(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try SecurityPolicyViolationEventImpl.get_referrer(instance);
    }

    pub fn get_blockedURI(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try SecurityPolicyViolationEventImpl.get_blockedURI(instance);
    }

    pub fn get_effectiveDirective(instance: *runtime.Instance) anyerror!DOMString {
        return try SecurityPolicyViolationEventImpl.get_effectiveDirective(instance);
    }

    pub fn get_violatedDirective(instance: *runtime.Instance) anyerror!DOMString {
        return try SecurityPolicyViolationEventImpl.get_violatedDirective(instance);
    }

    pub fn get_originalPolicy(instance: *runtime.Instance) anyerror!DOMString {
        return try SecurityPolicyViolationEventImpl.get_originalPolicy(instance);
    }

    pub fn get_sourceFile(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try SecurityPolicyViolationEventImpl.get_sourceFile(instance);
    }

    pub fn get_sample(instance: *runtime.Instance) anyerror!DOMString {
        return try SecurityPolicyViolationEventImpl.get_sample(instance);
    }

    pub fn get_disposition(instance: *runtime.Instance) anyerror!SecurityPolicyViolationEventDisposition {
        return try SecurityPolicyViolationEventImpl.get_disposition(instance);
    }

    pub fn get_statusCode(instance: *runtime.Instance) anyerror!u16 {
        return try SecurityPolicyViolationEventImpl.get_statusCode(instance);
    }

    pub fn get_lineNumber(instance: *runtime.Instance) anyerror!u32 {
        return try SecurityPolicyViolationEventImpl.get_lineNumber(instance);
    }

    pub fn get_columnNumber(instance: *runtime.Instance) anyerror!u32 {
        return try SecurityPolicyViolationEventImpl.get_columnNumber(instance);
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyerror!void {
        return try SecurityPolicyViolationEventImpl.call_stopImmediatePropagation(instance);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: DOMString, bubbles: bool, cancelable: bool) anyerror!void {
        
        return try SecurityPolicyViolationEventImpl.call_initEvent(instance, type_, bubbles, cancelable);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyerror!anyopaque {
        return try SecurityPolicyViolationEventImpl.call_composedPath(instance);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyerror!void {
        return try SecurityPolicyViolationEventImpl.call_stopPropagation(instance);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyerror!void {
        return try SecurityPolicyViolationEventImpl.call_preventDefault(instance);
    }

};
