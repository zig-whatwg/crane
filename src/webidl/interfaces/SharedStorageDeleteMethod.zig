//! Generated from: shared-storage.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SharedStorageDeleteMethodImpl = @import("impls").SharedStorageDeleteMethod;
const SharedStorageModifierMethod = @import("interfaces").SharedStorageModifierMethod;
const SharedStorageModifierMethodOptions = @import("dictionaries").SharedStorageModifierMethodOptions;
const DOMString = @import("typedefs").DOMString;

pub const SharedStorageDeleteMethod = struct {
    pub const Meta = struct {
        pub const name = "SharedStorageDeleteMethod";
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

    pub const vtable = runtime.buildVTable(SharedStorageDeleteMethod, .{
        .deinit_fn = &deinit_wrapper,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return SharedStorageDeleteMethodImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SharedStorageDeleteMethodImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, key: DOMString, options: SharedStorageModifierMethodOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try SharedStorageDeleteMethodImpl.constructor(instance, key, options);
        
        return instance;
    }

};
