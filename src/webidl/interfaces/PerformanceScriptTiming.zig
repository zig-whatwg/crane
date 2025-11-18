//! Generated from: long-animation-frames.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceScriptTimingImpl = @import("impls").PerformanceScriptTiming;
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const Window = @import("interfaces").Window;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const ScriptWindowAttribution = @import("enums").ScriptWindowAttribution;
const ScriptInvokerType = @import("enums").ScriptInvokerType;

pub const PerformanceScriptTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceScriptTiming";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *PerformanceEntry;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
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
            window: ?Window = null,
            windowAttribution: ScriptWindowAttribution = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PerformanceScriptTiming, .{
        .deinit_fn = &deinit_wrapper,

        .get_duration = &get_duration,
        .get_duration = &get_duration,
        .get_entryType = &get_entryType,
        .get_entryType = &get_entryType,
        .get_executionStart = &get_executionStart,
        .get_forcedStyleAndLayoutDuration = &get_forcedStyleAndLayoutDuration,
        .get_id = &get_id,
        .get_invoker = &get_invoker,
        .get_invokerType = &get_invokerType,
        .get_name = &get_name,
        .get_name = &get_name,
        .get_navigationId = &get_navigationId,
        .get_pauseDuration = &get_pauseDuration,
        .get_sourceCharPosition = &get_sourceCharPosition,
        .get_sourceFunctionName = &get_sourceFunctionName,
        .get_sourceURL = &get_sourceURL,
        .get_startTime = &get_startTime,
        .get_startTime = &get_startTime,
        .get_window = &get_window,
        .get_windowAttribution = &get_windowAttribution,

        .call_toJSON = &call_toJSON,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        PerformanceScriptTimingImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceScriptTimingImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceScriptTimingImpl.get_id(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceScriptTimingImpl.get_name(instance);
    }

    pub fn get_entryType(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceScriptTimingImpl.get_entryType(instance);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceScriptTimingImpl.get_startTime(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceScriptTimingImpl.get_duration(instance);
    }

    pub fn get_navigationId(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceScriptTimingImpl.get_navigationId(instance);
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

    pub fn get_window(instance: *runtime.Instance) anyerror!anyopaque {
        return try PerformanceScriptTimingImpl.get_window(instance);
    }

    pub fn get_windowAttribution(instance: *runtime.Instance) anyerror!ScriptWindowAttribution {
        return try PerformanceScriptTimingImpl.get_windowAttribution(instance);
    }

    /// Arguments for toJSON (WebIDL overloading)
    pub const ToJSONArgs = union(enum) {
        /// toJSON()
        no_params: void,
        /// toJSON()
        no_params: void,
    };

    pub fn call_toJSON(instance: *runtime.Instance, args: ToJSONArgs) anyerror!anyopaque {
        switch (args) {
            .no_params => return try PerformanceScriptTimingImpl.no_params(instance),
            .no_params => return try PerformanceScriptTimingImpl.no_params(instance),
        }
    }

};
