//! Generated from: webxr-lighting-estimation.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRLightProbeImpl = @import("impls").XRLightProbe;
const EventTarget = @import("interfaces").EventTarget;
const EventHandler = @import("typedefs").EventHandler;
const XRSpace = @import("interfaces").XRSpace;

pub const XRLightProbe = struct {
    pub const Meta = struct {
        pub const name = "XRLightProbe";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            probeSpace: XRSpace = undefined,
            onreflectionchange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRLightProbe, .{
        .deinit_fn = &deinit_wrapper,

        .get_onreflectionchange = &get_onreflectionchange,
        .get_probeSpace = &get_probeSpace,

        .set_onreflectionchange = &set_onreflectionchange,

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
        XRLightProbeImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRLightProbeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_probeSpace(instance: *runtime.Instance) anyerror!XRSpace {
        return try XRLightProbeImpl.get_probeSpace(instance);
    }

    pub fn get_onreflectionchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRLightProbeImpl.get_onreflectionchange(instance);
    }

    pub fn set_onreflectionchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRLightProbeImpl.set_onreflectionchange(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try XRLightProbeImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try XRLightProbeImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XRLightProbeImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XRLightProbeImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
