//! Generated from: media-source.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SourceBufferListImpl = @import("impls").SourceBufferList;
const EventTarget = @import("interfaces").EventTarget;
const SourceBuffer = @import("interfaces").SourceBuffer;
const EventHandler = @import("typedefs").EventHandler;

pub const SourceBufferList = struct {
    pub const Meta = struct {
        pub const name = "SourceBufferList";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            length: u32 = undefined,
            onaddsourcebuffer: EventHandler = undefined,
            onremovesourcebuffer: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SourceBufferList, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,
        .get_onaddsourcebuffer = &get_onaddsourcebuffer,
        .get_onremovesourcebuffer = &get_onremovesourcebuffer,

        .set_onaddsourcebuffer = &set_onaddsourcebuffer,
        .set_onremovesourcebuffer = &set_onremovesourcebuffer,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
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
        SourceBufferListImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SourceBufferListImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try SourceBufferListImpl.get_length(instance);
    }

    pub fn get_onaddsourcebuffer(instance: *runtime.Instance) anyerror!EventHandler {
        return try SourceBufferListImpl.get_onaddsourcebuffer(instance);
    }

    pub fn set_onaddsourcebuffer(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SourceBufferListImpl.set_onaddsourcebuffer(instance, value);
    }

    pub fn get_onremovesourcebuffer(instance: *runtime.Instance) anyerror!EventHandler {
        return try SourceBufferListImpl.get_onremovesourcebuffer(instance);
    }

    pub fn set_onremovesourcebuffer(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SourceBufferListImpl.set_onremovesourcebuffer(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try SourceBufferListImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try SourceBufferListImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try SourceBufferListImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try SourceBufferListImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
