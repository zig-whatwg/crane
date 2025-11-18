//! Generated from: shared-storage.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SharedStorageAppendMethodImpl = @import("impls").SharedStorageAppendMethod;
const SharedStorageModifierMethod = @import("interfaces").SharedStorageModifierMethod;
const SharedStorageModifierMethodOptions = @import("dictionaries").SharedStorageModifierMethodOptions;

pub const SharedStorageAppendMethod = struct {
    pub const Meta = struct {
        pub const name = "SharedStorageAppendMethod";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *SharedStorageModifierMethod;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "SharedStorageWorklet" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .SharedStorageWorklet = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SharedStorageAppendMethod, .{
        .deinit_fn = &deinit_wrapper,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SharedStorageAppendMethodImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SharedStorageAppendMethodImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, key: DOMString, value: DOMString, options: SharedStorageModifierMethodOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try SharedStorageAppendMethodImpl.constructor(instance, key, value, options);
        
        return instance;
    }

};
