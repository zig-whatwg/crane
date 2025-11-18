//! Generated from: webxr.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRBoundedReferenceSpaceImpl = @import("impls").XRBoundedReferenceSpace;
const XRReferenceSpace = @import("interfaces").XRReferenceSpace;
const FrozenArray<DOMPointReadOnly> = @import("interfaces").FrozenArray<DOMPointReadOnly>;

pub const XRBoundedReferenceSpace = struct {
    pub const Meta = struct {
        pub const name = "XRBoundedReferenceSpace";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *XRReferenceSpace;
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
            boundsGeometry: FrozenArray<DOMPointReadOnly> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRBoundedReferenceSpace, .{
        .deinit_fn = &deinit_wrapper,

        .get_boundsGeometry = &get_boundsGeometry,
        .get_onreset = &get_onreset,

        .set_onreset = &set_onreset,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getOffsetReferenceSpace = &call_getOffsetReferenceSpace,
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
        XRBoundedReferenceSpaceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRBoundedReferenceSpaceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onreset(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRBoundedReferenceSpaceImpl.get_onreset(instance);
    }

    pub fn set_onreset(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRBoundedReferenceSpaceImpl.set_onreset(instance, value);
    }

    pub fn get_boundsGeometry(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRBoundedReferenceSpaceImpl.get_boundsGeometry(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try XRBoundedReferenceSpaceImpl.call_dispatchEvent(instance, event);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getOffsetReferenceSpace(instance: *runtime.Instance, originOffset: XRRigidTransform) anyerror!XRReferenceSpace {
        // [NewObject] - Caller owns the returned object
        
        return try XRBoundedReferenceSpaceImpl.call_getOffsetReferenceSpace(instance, originOffset);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try XRBoundedReferenceSpaceImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XRBoundedReferenceSpaceImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XRBoundedReferenceSpaceImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
