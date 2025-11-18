//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DataTransferImpl = @import("../impls/DataTransfer.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        DataTransferImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DataTransferImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try DataTransferImpl.constructor(state);
        
        return instance;
    }

    pub fn get_dropEffect(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return DataTransferImpl.get_dropEffect(state);
    }

    pub fn set_dropEffect(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        DataTransferImpl.set_dropEffect(state, value);
    }

    pub fn get_effectAllowed(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return DataTransferImpl.get_effectAllowed(state);
    }

    pub fn set_effectAllowed(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        DataTransferImpl.set_effectAllowed(state, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_items(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_items) |cached| {
            return cached;
        }
        const value = DataTransferImpl.get_items(state);
        state.cached_items = value;
        return value;
    }

    pub fn get_types(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DataTransferImpl.get_types(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_files(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_files) |cached| {
            return cached;
        }
        const value = DataTransferImpl.get_files(state);
        state.cached_files = value;
        return value;
    }

    pub fn call_getData(instance: *runtime.Instance, format: runtime.DOMString) runtime.DOMString {
        const state = instance.getState(State);
        
        return DataTransferImpl.call_getData(state, format);
    }

    pub fn call_clearData(instance: *runtime.Instance, format: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return DataTransferImpl.call_clearData(state, format);
    }

    pub fn call_setDragImage(instance: *runtime.Instance, image: anyopaque, x: i32, y: i32) anyopaque {
        const state = instance.getState(State);
        
        return DataTransferImpl.call_setDragImage(state, image, x, y);
    }

    pub fn call_setData(instance: *runtime.Instance, format: runtime.DOMString, data: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return DataTransferImpl.call_setData(state, format, data);
    }

};
