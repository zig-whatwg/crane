//! Generated from: css-font-loading.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FontFaceSetImpl = @import("../impls/FontFaceSet.zig");
const EventTarget = @import("EventTarget.zig");

pub const FontFaceSet = struct {
    pub const Meta = struct {
        pub const name = "FontFaceSet";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            onloading: EventHandler = undefined,
            onloadingdone: EventHandler = undefined,
            onloadingerror: EventHandler = undefined,
            ready: Promise<FontFaceSet> = undefined,
            status: FontFaceSetLoadStatus = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const void _skipped = null;
    pub fn get__skipped() void {
        return null;
    }

    pub const vtable = runtime.buildVTable(FontFaceSet, .{
        .deinit_fn = &deinit_wrapper,

        .get__skipped = &get__skipped,
        .get_onloading = &get_onloading,
        .get_onloadingdone = &get_onloadingdone,
        .get_onloadingerror = &get_onloadingerror,
        .get_ready = &get_ready,
        .get_status = &get_status,

        .set_onloading = &set_onloading,
        .set_onloadingdone = &set_onloadingdone,
        .set_onloadingerror = &set_onloadingerror,

        .call_add = &call_add,
        .call_addEventListener = &call_addEventListener,
        .call_check = &call_check,
        .call_clear = &call_clear,
        .call_delete = &call_delete,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_load = &call_load,
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
        
        // Initialize the state (Impl receives full hierarchy)
        FontFaceSetImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        FontFaceSetImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onloading(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceSetImpl.get_onloading(state);
    }

    pub fn set_onloading(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        FontFaceSetImpl.set_onloading(state, value);
    }

    pub fn get_onloadingdone(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceSetImpl.get_onloadingdone(state);
    }

    pub fn set_onloadingdone(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        FontFaceSetImpl.set_onloadingdone(state, value);
    }

    pub fn get_onloadingerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceSetImpl.get_onloadingerror(state);
    }

    pub fn set_onloadingerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        FontFaceSetImpl.set_onloadingerror(state, value);
    }

    pub fn get_ready(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceSetImpl.get_ready(state);
    }

    pub fn get_status(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceSetImpl.get_status(state);
    }

    pub fn call_delete(instance: *runtime.Instance, font: anyopaque) bool {
        const state = instance.getState(State);
        
        return FontFaceSetImpl.call_delete(state, font);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FontFaceSetImpl.call_when(state, type_, options);
    }

    pub fn call_load(instance: *runtime.Instance, font: anyopaque, text: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FontFaceSetImpl.call_load(state, font, text);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return FontFaceSetImpl.call_dispatchEvent(state, event);
    }

    pub fn call_add(instance: *runtime.Instance, font: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FontFaceSetImpl.call_add(state, font);
    }

    pub fn call_clear(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceSetImpl.call_clear(state);
    }

    pub fn call_check(instance: *runtime.Instance, font: anyopaque, text: anyopaque) bool {
        const state = instance.getState(State);
        
        return FontFaceSetImpl.call_check(state, font, text);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FontFaceSetImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FontFaceSetImpl.call_removeEventListener(state, type_, callback, options);
    }

};
