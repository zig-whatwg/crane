//! Generated from: shared-storage.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SharedStorageWorkletImpl = @import("impls").SharedStorageWorklet;
const Worklet = @import("interfaces").Worklet;
const SharedStorageResponse = @import("typedefs").SharedStorageResponse;
const WorkletOptions = @import("dictionaries").WorkletOptions;
const SharedStorageUrlWithMetadata = @import("dictionaries").SharedStorageUrlWithMetadata;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;
const SharedStorageRunOperationMethodOptions = @import("dictionaries").SharedStorageRunOperationMethodOptions;

pub const SharedStorageWorklet = struct {
    pub const Meta = struct {
        pub const name = "SharedStorageWorklet";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Worklet;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SharedStorageWorklet, .{
        .deinit_fn = &deinit_wrapper,

        .call_addModule = &call_addModule,
        .call_run = &call_run,
        .call_selectURL = &call_selectURL,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return SharedStorageWorkletImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SharedStorageWorkletImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_run(instance: *runtime.Instance, name: DOMString, options: SharedStorageRunOperationMethodOptions) anyerror!anyopaque {
        
        return try SharedStorageWorkletImpl.call_run(instance, name, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_addModule(instance: *runtime.Instance, moduleURL: runtime.USVString, options: WorkletOptions) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try SharedStorageWorkletImpl.call_addModule(instance, moduleURL, options);
    }

    pub fn call_selectURL(instance: *runtime.Instance, name: DOMString, urls: anyopaque, options: SharedStorageRunOperationMethodOptions) anyerror!anyopaque {
        
        return try SharedStorageWorkletImpl.call_selectURL(instance, name, urls, options);
    }

};
