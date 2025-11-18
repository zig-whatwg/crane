//! Generated from: js-self-profiling.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ProfilerImpl = @import("impls").Profiler;
const EventTarget = @import("interfaces").EventTarget;
const Promise<ProfilerTrace> = @import("interfaces").Promise<ProfilerTrace>;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const ProfilerInitOptions = @import("dictionaries").ProfilerInitOptions;

pub const Profiler = struct {
    pub const Meta = struct {
        pub const name = "Profiler";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            sampleInterval: DOMHighResTimeStamp = undefined,
            stopped: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Profiler, .{
        .deinit_fn = &deinit_wrapper,

        .get_sampleInterval = &get_sampleInterval,
        .get_stopped = &get_stopped,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_stop = &call_stop,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ProfilerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ProfilerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, options: ProfilerInitOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try ProfilerImpl.constructor(instance, options);
        
        return instance;
    }

    pub fn get_sampleInterval(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try ProfilerImpl.get_sampleInterval(instance);
    }

    pub fn get_stopped(instance: *runtime.Instance) anyerror!bool {
        return try ProfilerImpl.get_stopped(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try ProfilerImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!anyopaque {
        return try ProfilerImpl.call_stop(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try ProfilerImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ProfilerImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ProfilerImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
