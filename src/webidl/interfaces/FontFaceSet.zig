//! Generated from: css-font-loading.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FontFaceSetImpl = @import("impls").FontFaceSet;
const EventTarget = @import("interfaces").EventTarget;
const CSSOMString = @import("interfaces").CSSOMString;
const Promise<sequence<FontFace>> = @import("interfaces").Promise<sequence<FontFace>>;
const Promise<FontFaceSet> = @import("interfaces").Promise<FontFaceSet>;
const FontFace = @import("interfaces").FontFace;
const EventHandler = @import("typedefs").EventHandler;
const FontFaceSetLoadStatus = @import("enums").FontFaceSetLoadStatus;

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
        
        // Initialize the instance (Impl receives full instance)
        FontFaceSetImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FontFaceSetImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onloading(instance: *runtime.Instance) anyerror!EventHandler {
        return try FontFaceSetImpl.get_onloading(instance);
    }

    pub fn set_onloading(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try FontFaceSetImpl.set_onloading(instance, value);
    }

    pub fn get_onloadingdone(instance: *runtime.Instance) anyerror!EventHandler {
        return try FontFaceSetImpl.get_onloadingdone(instance);
    }

    pub fn set_onloadingdone(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try FontFaceSetImpl.set_onloadingdone(instance, value);
    }

    pub fn get_onloadingerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try FontFaceSetImpl.get_onloadingerror(instance);
    }

    pub fn set_onloadingerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try FontFaceSetImpl.set_onloadingerror(instance, value);
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!anyopaque {
        return try FontFaceSetImpl.get_ready(instance);
    }

    pub fn get_status(instance: *runtime.Instance) anyerror!FontFaceSetLoadStatus {
        return try FontFaceSetImpl.get_status(instance);
    }

    pub fn call_delete(instance: *runtime.Instance, font: FontFace) anyerror!bool {
        
        return try FontFaceSetImpl.call_delete(instance, font);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try FontFaceSetImpl.call_when(instance, type_, options);
    }

    pub fn call_load(instance: *runtime.Instance, font: anyopaque, text: anyopaque) anyerror!anyopaque {
        
        return try FontFaceSetImpl.call_load(instance, font, text);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try FontFaceSetImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_add(instance: *runtime.Instance, font: FontFace) anyerror!FontFaceSet {
        
        return try FontFaceSetImpl.call_add(instance, font);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try FontFaceSetImpl.call_clear(instance);
    }

    pub fn call_check(instance: *runtime.Instance, font: anyopaque, text: anyopaque) anyerror!bool {
        
        return try FontFaceSetImpl.call_check(instance, font, text);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try FontFaceSetImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try FontFaceSetImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
