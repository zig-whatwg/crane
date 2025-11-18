//! Generated from: web-nfc.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NDEFMessageImpl = @import("impls").NDEFMessage;
const FrozenArray<NDEFRecord> = @import("interfaces").FrozenArray<NDEFRecord>;
const NDEFMessageInit = @import("dictionaries").NDEFMessageInit;

pub const NDEFMessage = struct {
    pub const Meta = struct {
        pub const name = "NDEFMessage";
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
            records: FrozenArray<NDEFRecord> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NDEFMessage, .{
        .deinit_fn = &deinit_wrapper,

        .get_records = &get_records,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        NDEFMessageImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NDEFMessageImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, messageInit: NDEFMessageInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try NDEFMessageImpl.constructor(instance, messageInit);
        
        return instance;
    }

    pub fn get_records(instance: *runtime.Instance) anyerror!anyopaque {
        return try NDEFMessageImpl.get_records(instance);
    }

};
