//! Generated from: webxr.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRPermissionStatusImpl = @import("impls").XRPermissionStatus;
const PermissionStatus = @import("interfaces").PermissionStatus;
const FrozenArray<DOMString> = @import("interfaces").FrozenArray<DOMString>;

pub const XRPermissionStatus = struct {
    pub const Meta = struct {
        pub const name = "XRPermissionStatus";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *PermissionStatus;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            granted: FrozenArray<DOMString> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRPermissionStatus, .{
        .deinit_fn = &deinit_wrapper,

        .get_granted = &get_granted,
        .get_name = &get_name,
        .get_onchange = &get_onchange,
        .get_state = &get_state,

        .set_granted = &set_granted,
        .set_onchange = &set_onchange,

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
        XRPermissionStatusImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRPermissionStatusImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!PermissionState {
        return try XRPermissionStatusImpl.get_state(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try XRPermissionStatusImpl.get_name(instance);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRPermissionStatusImpl.get_onchange(instance);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRPermissionStatusImpl.set_onchange(instance, value);
    }

    pub fn get_granted(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRPermissionStatusImpl.get_granted(instance);
    }

    pub fn set_granted(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try XRPermissionStatusImpl.set_granted(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try XRPermissionStatusImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try XRPermissionStatusImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XRPermissionStatusImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XRPermissionStatusImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
