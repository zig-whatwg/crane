//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigationImpl = @import("impls").Navigation;
const EventTarget = @import("interfaces").EventTarget;
const NavigationResult = @import("dictionaries").NavigationResult;
const NavigationActivation = @import("interfaces").NavigationActivation;
const NavigationNavigateOptions = @import("dictionaries").NavigationNavigateOptions;
const NavigationOptions = @import("dictionaries").NavigationOptions;
const NavigationTransition = @import("interfaces").NavigationTransition;
const NavigationHistoryEntry = @import("interfaces").NavigationHistoryEntry;
const NavigationReloadOptions = @import("dictionaries").NavigationReloadOptions;
const EventHandler = @import("typedefs").EventHandler;
const NavigationUpdateCurrentEntryOptions = @import("dictionaries").NavigationUpdateCurrentEntryOptions;

pub const Navigation = struct {
    pub const Meta = struct {
        pub const name = "Navigation";
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
            currentEntry: ?NavigationHistoryEntry = null,
            transition: ?NavigationTransition = null,
            activation: ?NavigationActivation = null,
            canGoBack: bool = undefined,
            canGoForward: bool = undefined,
            onnavigate: EventHandler = undefined,
            onnavigatesuccess: EventHandler = undefined,
            onnavigateerror: EventHandler = undefined,
            oncurrententrychange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Navigation, .{
        .deinit_fn = &deinit_wrapper,

        .get_activation = &get_activation,
        .get_canGoBack = &get_canGoBack,
        .get_canGoForward = &get_canGoForward,
        .get_currentEntry = &get_currentEntry,
        .get_oncurrententrychange = &get_oncurrententrychange,
        .get_onnavigate = &get_onnavigate,
        .get_onnavigateerror = &get_onnavigateerror,
        .get_onnavigatesuccess = &get_onnavigatesuccess,
        .get_transition = &get_transition,

        .set_oncurrententrychange = &set_oncurrententrychange,
        .set_onnavigate = &set_onnavigate,
        .set_onnavigateerror = &set_onnavigateerror,
        .set_onnavigatesuccess = &set_onnavigatesuccess,

        .call_addEventListener = &call_addEventListener,
        .call_back = &call_back,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_entries = &call_entries,
        .call_forward = &call_forward,
        .call_navigate = &call_navigate,
        .call_reload = &call_reload,
        .call_removeEventListener = &call_removeEventListener,
        .call_traverseTo = &call_traverseTo,
        .call_updateCurrentEntry = &call_updateCurrentEntry,
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
        NavigationImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_currentEntry(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigationImpl.get_currentEntry(instance);
    }

    pub fn get_transition(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigationImpl.get_transition(instance);
    }

    pub fn get_activation(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigationImpl.get_activation(instance);
    }

    pub fn get_canGoBack(instance: *runtime.Instance) anyerror!bool {
        return try NavigationImpl.get_canGoBack(instance);
    }

    pub fn get_canGoForward(instance: *runtime.Instance) anyerror!bool {
        return try NavigationImpl.get_canGoForward(instance);
    }

    pub fn get_onnavigate(instance: *runtime.Instance) anyerror!EventHandler {
        return try NavigationImpl.get_onnavigate(instance);
    }

    pub fn set_onnavigate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NavigationImpl.set_onnavigate(instance, value);
    }

    pub fn get_onnavigatesuccess(instance: *runtime.Instance) anyerror!EventHandler {
        return try NavigationImpl.get_onnavigatesuccess(instance);
    }

    pub fn set_onnavigatesuccess(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NavigationImpl.set_onnavigatesuccess(instance, value);
    }

    pub fn get_onnavigateerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try NavigationImpl.get_onnavigateerror(instance);
    }

    pub fn set_onnavigateerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NavigationImpl.set_onnavigateerror(instance, value);
    }

    pub fn get_oncurrententrychange(instance: *runtime.Instance) anyerror!EventHandler {
        return try NavigationImpl.get_oncurrententrychange(instance);
    }

    pub fn set_oncurrententrychange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NavigationImpl.set_oncurrententrychange(instance, value);
    }

    pub fn call_reload(instance: *runtime.Instance, options: NavigationReloadOptions) anyerror!NavigationResult {
        
        return try NavigationImpl.call_reload(instance, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try NavigationImpl.call_when(instance, type_, options);
    }

    pub fn call_back(instance: *runtime.Instance, options: NavigationOptions) anyerror!NavigationResult {
        
        return try NavigationImpl.call_back(instance, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try NavigationImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_entries(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigationImpl.call_entries(instance);
    }

    pub fn call_navigate(instance: *runtime.Instance, url: runtime.USVString, options: NavigationNavigateOptions) anyerror!NavigationResult {
        
        return try NavigationImpl.call_navigate(instance, url, options);
    }

    pub fn call_traverseTo(instance: *runtime.Instance, key: DOMString, options: NavigationOptions) anyerror!NavigationResult {
        
        return try NavigationImpl.call_traverseTo(instance, key, options);
    }

    pub fn call_forward(instance: *runtime.Instance, options: NavigationOptions) anyerror!NavigationResult {
        
        return try NavigationImpl.call_forward(instance, options);
    }

    pub fn call_updateCurrentEntry(instance: *runtime.Instance, options: NavigationUpdateCurrentEntryOptions) anyerror!void {
        
        return try NavigationImpl.call_updateCurrentEntry(instance, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try NavigationImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try NavigationImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
