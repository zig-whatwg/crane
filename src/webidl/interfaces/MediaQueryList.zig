//! Generated from: cssom-view.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaQueryListImpl = @import("impls").MediaQueryList;
const EventTarget = @import("interfaces").EventTarget;
const EventListener = @import("interfaces").EventListener;
const CSSOMString = @import("interfaces").CSSOMString;
const EventHandler = @import("typedefs").EventHandler;

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
        
        // Initialize the instance (Impl receives full instance)
        MediaQueryListImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaQueryListImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_media(instance: *runtime.Instance) anyerror!anyopaque {
        return try MediaQueryListImpl.get_media(instance);
    }

    pub fn get_matches(instance: *runtime.Instance) anyerror!bool {
        return try MediaQueryListImpl.get_matches(instance);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaQueryListImpl.get_onchange(instance);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaQueryListImpl.set_onchange(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try MediaQueryListImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_removeListener(instance: *runtime.Instance, callback: anyopaque) anyerror!void {
        
        return try MediaQueryListImpl.call_removeListener(instance, callback);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try MediaQueryListImpl.call_when(instance, type_, options);
    }

    pub fn call_addListener(instance: *runtime.Instance, callback: anyopaque) anyerror!void {
        
        return try MediaQueryListImpl.call_addListener(instance, callback);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try MediaQueryListImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try MediaQueryListImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
