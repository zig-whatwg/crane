//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WindowEventHandlersImpl = @import("impls").WindowEventHandlers;
const OnBeforeUnloadEventHandler = @import("typedefs").OnBeforeUnloadEventHandler;
const EventHandler = @import("typedefs").EventHandler;

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
        
        // Initialize the instance (Impl receives full instance)
        WindowEventHandlersImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WindowEventHandlersImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onafterprint(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowEventHandlersImpl.get_onafterprint(instance);
    }

    pub fn set_onafterprint(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_onafterprint(instance, value);
    }

    pub fn get_onbeforeprint(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowEventHandlersImpl.get_onbeforeprint(instance);
    }

    pub fn set_onbeforeprint(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_onbeforeprint(instance, value);
    }

    pub fn get_onbeforeunload(instance: *runtime.Instance) anyerror!OnBeforeUnloadEventHandler {
        return try WindowEventHandlersImpl.get_onbeforeunload(instance);
    }

    pub fn set_onbeforeunload(instance: *runtime.Instance, value: OnBeforeUnloadEventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_onbeforeunload(instance, value);
    }

    pub fn get_onhashchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowEventHandlersImpl.get_onhashchange(instance);
    }

    pub fn set_onhashchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_onhashchange(instance, value);
    }

    pub fn get_onlanguagechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowEventHandlersImpl.get_onlanguagechange(instance);
    }

    pub fn set_onlanguagechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_onlanguagechange(instance, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowEventHandlersImpl.get_onmessage(instance);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_onmessage(instance, value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowEventHandlersImpl.get_onmessageerror(instance);
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_onmessageerror(instance, value);
    }

    pub fn get_onoffline(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowEventHandlersImpl.get_onoffline(instance);
    }

    pub fn set_onoffline(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_onoffline(instance, value);
    }

    pub fn get_ononline(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowEventHandlersImpl.get_ononline(instance);
    }

    pub fn set_ononline(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_ononline(instance, value);
    }

    pub fn get_onpagehide(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowEventHandlersImpl.get_onpagehide(instance);
    }

    pub fn set_onpagehide(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_onpagehide(instance, value);
    }

    pub fn get_onpagereveal(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowEventHandlersImpl.get_onpagereveal(instance);
    }

    pub fn set_onpagereveal(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_onpagereveal(instance, value);
    }

    pub fn get_onpageshow(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowEventHandlersImpl.get_onpageshow(instance);
    }

    pub fn set_onpageshow(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_onpageshow(instance, value);
    }

    pub fn get_onpageswap(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowEventHandlersImpl.get_onpageswap(instance);
    }

    pub fn set_onpageswap(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_onpageswap(instance, value);
    }

    pub fn get_onpopstate(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowEventHandlersImpl.get_onpopstate(instance);
    }

    pub fn set_onpopstate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_onpopstate(instance, value);
    }

    pub fn get_onrejectionhandled(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowEventHandlersImpl.get_onrejectionhandled(instance);
    }

    pub fn set_onrejectionhandled(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_onrejectionhandled(instance, value);
    }

    pub fn get_onstorage(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowEventHandlersImpl.get_onstorage(instance);
    }

    pub fn set_onstorage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_onstorage(instance, value);
    }

    pub fn get_onunhandledrejection(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowEventHandlersImpl.get_onunhandledrejection(instance);
    }

    pub fn set_onunhandledrejection(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_onunhandledrejection(instance, value);
    }

    pub fn get_onunload(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowEventHandlersImpl.get_onunload(instance);
    }

    pub fn set_onunload(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_onunload(instance, value);
    }

    pub fn get_ongamepadconnected(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowEventHandlersImpl.get_ongamepadconnected(instance);
    }

    pub fn set_ongamepadconnected(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_ongamepadconnected(instance, value);
    }

    pub fn get_ongamepaddisconnected(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowEventHandlersImpl.get_ongamepaddisconnected(instance);
    }

    pub fn set_ongamepaddisconnected(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_ongamepaddisconnected(instance, value);
    }

    pub fn get_onportalactivate(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowEventHandlersImpl.get_onportalactivate(instance);
    }

    pub fn set_onportalactivate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowEventHandlersImpl.set_onportalactivate(instance, value);
    }

};
