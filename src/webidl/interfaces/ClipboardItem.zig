//! Generated from: clipboard-apis.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ClipboardItemImpl = @import("impls").ClipboardItem;
const ClipboardItemOptions = @import("dictionaries").ClipboardItemOptions;
const PresentationStyle = @import("enums").PresentationStyle;
const Promise<Blob> = @import("interfaces").Promise<Blob>;
const FrozenArray<DOMString> = @import("interfaces").FrozenArray<DOMString>;

pub const ClipboardItem = struct {
    pub const Meta = struct {
        pub const name = "ClipboardItem";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
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
            presentationStyle: PresentationStyle = undefined,
            types: FrozenArray<DOMString> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ClipboardItem, .{
        .deinit_fn = &deinit_wrapper,

        .get_presentationStyle = &get_presentationStyle,
        .get_types = &get_types,

        .call_getType = &call_getType,
        .call_supports = &call_supports,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ClipboardItemImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ClipboardItemImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, items: anyopaque, options: ClipboardItemOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try ClipboardItemImpl.constructor(instance, items, options);
        
        return instance;
    }

    pub fn get_presentationStyle(instance: *runtime.Instance) anyerror!PresentationStyle {
        return try ClipboardItemImpl.get_presentationStyle(instance);
    }

    pub fn get_types(instance: *runtime.Instance) anyerror!anyopaque {
        return try ClipboardItemImpl.get_types(instance);
    }

    pub fn call_getType(instance: *runtime.Instance, type_: DOMString) anyerror!anyopaque {
        
        return try ClipboardItemImpl.call_getType(instance, type_);
    }

    pub fn call_supports(instance: *runtime.Instance, type_: DOMString) anyerror!bool {
        
        return try ClipboardItemImpl.call_supports(instance, type_);
    }

};
