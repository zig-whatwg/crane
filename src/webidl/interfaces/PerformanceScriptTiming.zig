//! Generated from: long-animation-frames.idl
//! Generated at: 2025-11-28T03:24:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceScriptTimingImpl = @import("impls").PerformanceScriptTiming;
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const Window = @import("interfaces").Window;
const ScriptWindowAttribution = @import("enums").ScriptWindowAttribution;
const ScriptInvokerType = @import("enums").ScriptInvokerType;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const DOMString = @import("typedefs").DOMString;

pub const PerformanceScriptTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceScriptTiming";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *PerformanceEntry;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "startTime", "get_startTime", null },
            .{ "duration", "get_duration", null },
            .{ "name", "get_name", null },
            .{ "entryType", "get_entryType", null },
            .{ "invokerType", "get_invokerType", null },
            .{ "invoker", "get_invoker", null },
            .{ "executionStart", "get_executionStart", null },
            .{ "sourceURL", "get_sourceURL", null },
            .{ "sourceFunctionName", "get_sourceFunctionName", null },
            .{ "sourceCharPosition", "get_sourceCharPosition", null },
            .{ "pauseDuration", "get_pauseDuration", null },
            .{ "forcedStyleAndLayoutDuration", "get_forcedStyleAndLayoutDuration", null },
            .{ "window", "get_window", null },
            .{ "windowAttribution", "get_windowAttribution", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "startTime", "get_startTime", null },
            .{ "duration", "get_duration", null },
            .{ "name", "get_name", null },
            .{ "entryType", "get_entryType", null },
            .{ "invokerType", "get_invokerType", null },
            .{ "invoker", "get_invoker", null },
            .{ "executionStart", "get_executionStart", null },
            .{ "sourceURL", "get_sourceURL", null },
            .{ "sourceFunctionName", "get_sourceFunctionName", null },
            .{ "sourceCharPosition", "get_sourceCharPosition", null },
            .{ "pauseDuration", "get_pauseDuration", null },
            .{ "forcedStyleAndLayoutDuration", "get_forcedStyleAndLayoutDuration", null },
            .{ "window", "get_window", null },
            .{ "windowAttribution", "get_windowAttribution", null },
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
            startTime: DOMHighResTimeStamp = undefined,
            duration: DOMHighResTimeStamp = undefined,
            name: runtime.DOMString = undefined,
            entryType: runtime.DOMString = undefined,
            invokerType: ScriptInvokerType = undefined,
            invoker: runtime.DOMString = undefined,
            executionStart: DOMHighResTimeStamp = undefined,
            sourceURL: runtime.DOMString = undefined,
            sourceFunctionName: runtime.DOMString = undefined,
            sourceCharPosition: i64 = undefined,
            pauseDuration: DOMHighResTimeStamp = undefined,
            forcedStyleAndLayoutDuration: DOMHighResTimeStamp = undefined,
            window: ?*runtime.Instance = null,
            windowAttribution: ScriptWindowAttribution = undefined,
            _internal: ?*PerformanceScriptTimingImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_duration = &get_duration,
        .get_entryType = &get_entryType,
        .get_executionStart = &get_executionStart,
        .get_forcedStyleAndLayoutDuration = &get_forcedStyleAndLayoutDuration,
        .get_invoker = &get_invoker,
        .get_invokerType = &get_invokerType,
        .get_name = &get_name,
        .get_pauseDuration = &get_pauseDuration,
        .get_sourceCharPosition = &get_sourceCharPosition,
        .get_sourceFunctionName = &get_sourceFunctionName,
        .get_sourceURL = &get_sourceURL,
        .get_startTime = &get_startTime,
        .get_window = &get_window,
        .get_windowAttribution = &get_windowAttribution,

        .call_toJSON = &call_toJSON,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PerformanceScriptTimingImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceScriptTimingImpl.deinit(instance);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceScriptTimingImpl.get_startTime(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceScriptTimingImpl.get_duration(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceScriptTimingImpl.get_name(instance);
    }

    pub fn get_entryType(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceScriptTimingImpl.get_entryType(instance);
    }

    pub fn get_invokerType(instance: *runtime.Instance) anyerror!ScriptInvokerType {
        return try PerformanceScriptTimingImpl.get_invokerType(instance);
    }

    pub fn get_invoker(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceScriptTimingImpl.get_invoker(instance);
    }

    pub fn get_executionStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceScriptTimingImpl.get_executionStart(instance);
    }

    pub fn get_sourceURL(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceScriptTimingImpl.get_sourceURL(instance);
    }

    pub fn get_sourceFunctionName(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceScriptTimingImpl.get_sourceFunctionName(instance);
    }

    pub fn get_sourceCharPosition(instance: *runtime.Instance) anyerror!i64 {
        return try PerformanceScriptTimingImpl.get_sourceCharPosition(instance);
    }

    pub fn get_pauseDuration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceScriptTimingImpl.get_pauseDuration(instance);
    }

    pub fn get_forcedStyleAndLayoutDuration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceScriptTimingImpl.get_forcedStyleAndLayoutDuration(instance);
    }

    pub fn get_window(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try PerformanceScriptTimingImpl.get_window(instance);
    }

    pub fn get_windowAttribution(instance: *runtime.Instance) anyerror!ScriptWindowAttribution {
        return try PerformanceScriptTimingImpl.get_windowAttribution(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PerformanceScriptTimingImpl.call_toJSON(instance);
    }

};
