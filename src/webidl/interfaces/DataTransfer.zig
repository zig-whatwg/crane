//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DataTransferImpl = @import("impls").DataTransfer;
const Element = @import("interfaces").Element;
const DataTransferItemList = @import("interfaces").DataTransferItemList;
const FrozenArray<DOMString> = @import("interfaces").FrozenArray<DOMString>;
const FileList = @import("interfaces").FileList;

pub const DataTransfer = struct {
    pub const Meta = struct {
        pub const name = "DataTransfer";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            dropEffect: runtime.DOMString = undefined,
            effectAllowed: runtime.DOMString = undefined,
            items: DataTransferItemList = undefined,
            types: FrozenArray<DOMString> = undefined,
            files: FileList = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DataTransfer, .{
        .deinit_fn = &deinit_wrapper,

        .get_dropEffect = &get_dropEffect,
        .get_effectAllowed = &get_effectAllowed,
        .get_files = &get_files,
        .get_items = &get_items,
        .get_types = &get_types,

        .set_dropEffect = &set_dropEffect,
        .set_effectAllowed = &set_effectAllowed,

        .call_clearData = &call_clearData,
        .call_getData = &call_getData,
        .call_setData = &call_setData,
        .call_setDragImage = &call_setDragImage,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        DataTransferImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DataTransferImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try DataTransferImpl.constructor(instance);
        
        return instance;
    }

    pub fn get_dropEffect(instance: *runtime.Instance) anyerror!DOMString {
        return try DataTransferImpl.get_dropEffect(instance);
    }

    pub fn set_dropEffect(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try DataTransferImpl.set_dropEffect(instance, value);
    }

    pub fn get_effectAllowed(instance: *runtime.Instance) anyerror!DOMString {
        return try DataTransferImpl.get_effectAllowed(instance);
    }

    pub fn set_effectAllowed(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try DataTransferImpl.set_effectAllowed(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_items(instance: *runtime.Instance) anyerror!DataTransferItemList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_items) |cached| {
            return cached;
        }
        const value = try DataTransferImpl.get_items(instance);
        state.cached_items = value;
        return value;
    }

    pub fn get_types(instance: *runtime.Instance) anyerror!anyopaque {
        return try DataTransferImpl.get_types(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_files(instance: *runtime.Instance) anyerror!FileList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_files) |cached| {
            return cached;
        }
        const value = try DataTransferImpl.get_files(instance);
        state.cached_files = value;
        return value;
    }

    pub fn call_getData(instance: *runtime.Instance, format: DOMString) anyerror!DOMString {
        
        return try DataTransferImpl.call_getData(instance, format);
    }

    pub fn call_clearData(instance: *runtime.Instance, format: DOMString) anyerror!void {
        
        return try DataTransferImpl.call_clearData(instance, format);
    }

    pub fn call_setDragImage(instance: *runtime.Instance, image: Element, x: i32, y: i32) anyerror!void {
        
        return try DataTransferImpl.call_setDragImage(instance, image, x, y);
    }

    pub fn call_setData(instance: *runtime.Instance, format: DOMString, data: DOMString) anyerror!void {
        
        return try DataTransferImpl.call_setData(instance, format, data);
    }

};
