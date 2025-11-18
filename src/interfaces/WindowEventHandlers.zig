//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WindowEventHandlersImpl = @import("../impls/WindowEventHandlers.zig");

pub const WindowEventHandlers = struct {
    pub const Meta = struct {
        pub const name = "WindowEventHandlers";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            onafterprint: EventHandler = undefined,
            onbeforeprint: EventHandler = undefined,
            onbeforeunload: OnBeforeUnloadEventHandler = undefined,
            onhashchange: EventHandler = undefined,
            onlanguagechange: EventHandler = undefined,
            onmessage: EventHandler = undefined,
            onmessageerror: EventHandler = undefined,
            onoffline: EventHandler = undefined,
            ononline: EventHandler = undefined,
            onpagehide: EventHandler = undefined,
            onpagereveal: EventHandler = undefined,
            onpageshow: EventHandler = undefined,
            onpageswap: EventHandler = undefined,
            onpopstate: EventHandler = undefined,
            onrejectionhandled: EventHandler = undefined,
            onstorage: EventHandler = undefined,
            onunhandledrejection: EventHandler = undefined,
            onunload: EventHandler = undefined,
            ongamepadconnected: EventHandler = undefined,
            ongamepaddisconnected: EventHandler = undefined,
            onportalactivate: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WindowEventHandlers, .{
        .deinit_fn = &deinit_wrapper,

        .get_onafterprint = &get_onafterprint,
        .get_onbeforeprint = &get_onbeforeprint,
        .get_onbeforeunload = &get_onbeforeunload,
        .get_ongamepadconnected = &get_ongamepadconnected,
        .get_ongamepaddisconnected = &get_ongamepaddisconnected,
        .get_onhashchange = &get_onhashchange,
        .get_onlanguagechange = &get_onlanguagechange,
        .get_onmessage = &get_onmessage,
        .get_onmessageerror = &get_onmessageerror,
        .get_onoffline = &get_onoffline,
        .get_ononline = &get_ononline,
        .get_onpagehide = &get_onpagehide,
        .get_onpagereveal = &get_onpagereveal,
        .get_onpageshow = &get_onpageshow,
        .get_onpageswap = &get_onpageswap,
        .get_onpopstate = &get_onpopstate,
        .get_onportalactivate = &get_onportalactivate,
        .get_onrejectionhandled = &get_onrejectionhandled,
        .get_onstorage = &get_onstorage,
        .get_onunhandledrejection = &get_onunhandledrejection,
        .get_onunload = &get_onunload,

        .set_onafterprint = &set_onafterprint,
        .set_onbeforeprint = &set_onbeforeprint,
        .set_onbeforeunload = &set_onbeforeunload,
        .set_ongamepadconnected = &set_ongamepadconnected,
        .set_ongamepaddisconnected = &set_ongamepaddisconnected,
        .set_onhashchange = &set_onhashchange,
        .set_onlanguagechange = &set_onlanguagechange,
        .set_onmessage = &set_onmessage,
        .set_onmessageerror = &set_onmessageerror,
        .set_onoffline = &set_onoffline,
        .set_ononline = &set_ononline,
        .set_onpagehide = &set_onpagehide,
        .set_onpagereveal = &set_onpagereveal,
        .set_onpageshow = &set_onpageshow,
        .set_onpageswap = &set_onpageswap,
        .set_onpopstate = &set_onpopstate,
        .set_onportalactivate = &set_onportalactivate,
        .set_onrejectionhandled = &set_onrejectionhandled,
        .set_onstorage = &set_onstorage,
        .set_onunhandledrejection = &set_onunhandledrejection,
        .set_onunload = &set_onunload,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        WindowEventHandlersImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onafterprint(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_onafterprint(state);
    }

    pub fn set_onafterprint(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_onafterprint(state, value);
    }

    pub fn get_onbeforeprint(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_onbeforeprint(state);
    }

    pub fn set_onbeforeprint(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_onbeforeprint(state, value);
    }

    pub fn get_onbeforeunload(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_onbeforeunload(state);
    }

    pub fn set_onbeforeunload(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_onbeforeunload(state, value);
    }

    pub fn get_onhashchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_onhashchange(state);
    }

    pub fn set_onhashchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_onhashchange(state, value);
    }

    pub fn get_onlanguagechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_onlanguagechange(state);
    }

    pub fn set_onlanguagechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_onlanguagechange(state, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_onmessage(state);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_onmessage(state, value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_onmessageerror(state);
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_onmessageerror(state, value);
    }

    pub fn get_onoffline(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_onoffline(state);
    }

    pub fn set_onoffline(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_onoffline(state, value);
    }

    pub fn get_ononline(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_ononline(state);
    }

    pub fn set_ononline(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_ononline(state, value);
    }

    pub fn get_onpagehide(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_onpagehide(state);
    }

    pub fn set_onpagehide(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_onpagehide(state, value);
    }

    pub fn get_onpagereveal(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_onpagereveal(state);
    }

    pub fn set_onpagereveal(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_onpagereveal(state, value);
    }

    pub fn get_onpageshow(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_onpageshow(state);
    }

    pub fn set_onpageshow(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_onpageshow(state, value);
    }

    pub fn get_onpageswap(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_onpageswap(state);
    }

    pub fn set_onpageswap(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_onpageswap(state, value);
    }

    pub fn get_onpopstate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_onpopstate(state);
    }

    pub fn set_onpopstate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_onpopstate(state, value);
    }

    pub fn get_onrejectionhandled(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_onrejectionhandled(state);
    }

    pub fn set_onrejectionhandled(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_onrejectionhandled(state, value);
    }

    pub fn get_onstorage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_onstorage(state);
    }

    pub fn set_onstorage(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_onstorage(state, value);
    }

    pub fn get_onunhandledrejection(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_onunhandledrejection(state);
    }

    pub fn set_onunhandledrejection(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_onunhandledrejection(state, value);
    }

    pub fn get_onunload(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_onunload(state);
    }

    pub fn set_onunload(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_onunload(state, value);
    }

    pub fn get_ongamepadconnected(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_ongamepadconnected(state);
    }

    pub fn set_ongamepadconnected(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_ongamepadconnected(state, value);
    }

    pub fn get_ongamepaddisconnected(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_ongamepaddisconnected(state);
    }

    pub fn set_ongamepaddisconnected(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_ongamepaddisconnected(state, value);
    }

    pub fn get_onportalactivate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowEventHandlersImpl.get_onportalactivate(state);
    }

    pub fn set_onportalactivate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowEventHandlersImpl.set_onportalactivate(state, value);
    }

};
