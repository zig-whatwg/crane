//! Generated from: mediaqueries-5.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PreferenceObjectImpl = @import("impls").PreferenceObject;
const EventTarget = @import("interfaces").EventTarget;
const EventHandler = @import("typedefs").EventHandler;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const DOMString = @import("typedefs").DOMString;
const FrozenArray<DOMString> = @import("interfaces").FrozenArray<DOMString>;

pub const PreferenceObject = struct {
    pub const Meta = struct {
        pub const name = "PreferenceObject";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            override: ?runtime.DOMString = null,
            value: runtime.DOMString = undefined,
            validValues: FrozenArray<DOMString> = undefined,
            onchange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PreferenceObject, .{
        .deinit_fn = &deinit_wrapper,

        .get_onchange = &get_onchange,
        .get_override = &get_override,
        .get_validValues = &get_validValues,
        .get_value = &get_value,

        .set_onchange = &set_onchange,

        .call_addEventListener = &call_addEventListener,
        .call_clearOverride = &call_clearOverride,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_requestOverride = &call_requestOverride,
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
        PreferenceObjectImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PreferenceObjectImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_override(instance: *runtime.Instance) anyerror!anyopaque {
        return try PreferenceObjectImpl.get_override(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!DOMString {
        return try PreferenceObjectImpl.get_value(instance);
    }

    pub fn get_validValues(instance: *runtime.Instance) anyerror!anyopaque {
        return try PreferenceObjectImpl.get_validValues(instance);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try PreferenceObjectImpl.get_onchange(instance);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PreferenceObjectImpl.set_onchange(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try PreferenceObjectImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_requestOverride(instance: *runtime.Instance, value: anyopaque) anyerror!anyopaque {
        
        return try PreferenceObjectImpl.call_requestOverride(instance, value);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try PreferenceObjectImpl.call_when(instance, type_, options);
    }

    pub fn call_clearOverride(instance: *runtime.Instance) anyerror!void {
        return try PreferenceObjectImpl.call_clearOverride(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try PreferenceObjectImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try PreferenceObjectImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
