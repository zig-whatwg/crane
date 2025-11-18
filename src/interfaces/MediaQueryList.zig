//! Generated from: cssom-view.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaQueryListImpl = @import("../impls/MediaQueryList.zig");
const EventTarget = @import("EventTarget.zig");

pub const MediaQueryList = struct {
    pub const Meta = struct {
        pub const name = "MediaQueryList";
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
            media: CSSOMString = undefined,
            matches: bool = undefined,
            onchange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MediaQueryList, .{
        .deinit_fn = &deinit_wrapper,

        .get_matches = &get_matches,
        .get_media = &get_media,
        .get_onchange = &get_onchange,

        .set_onchange = &set_onchange,

        .call_addEventListener = &call_addEventListener,
        .call_addListener = &call_addListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_removeListener = &call_removeListener,
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
        MediaQueryListImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MediaQueryListImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_media(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaQueryListImpl.get_media(state);
    }

    pub fn get_matches(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return MediaQueryListImpl.get_matches(state);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaQueryListImpl.get_onchange(state);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaQueryListImpl.set_onchange(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return MediaQueryListImpl.call_dispatchEvent(state, event);
    }

    pub fn call_removeListener(instance: *runtime.Instance, callback: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaQueryListImpl.call_removeListener(state, callback);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaQueryListImpl.call_when(state, type_, options);
    }

    pub fn call_addListener(instance: *runtime.Instance, callback: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaQueryListImpl.call_addListener(state, callback);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaQueryListImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaQueryListImpl.call_removeEventListener(state, type_, callback, options);
    }

};
