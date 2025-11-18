//! Generated from: content-index.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ContentIndexImpl = @import("impls").ContentIndex;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const ContentDescription = @import("dictionaries").ContentDescription;
const Promise<sequence<ContentDescription>> = @import("interfaces").Promise<sequence<ContentDescription>>;

pub const ContentIndex = struct {
    pub const Meta = struct {
        pub const name = "ContentIndex";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ContentIndex, .{
        .deinit_fn = &deinit_wrapper,

        .call_add = &call_add,
        .call_delete = &call_delete,
        .call_getAll = &call_getAll,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ContentIndexImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ContentIndexImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_delete(instance: *runtime.Instance, id: DOMString) anyerror!anyopaque {
        
        return try ContentIndexImpl.call_delete(instance, id);
    }

    pub fn call_add(instance: *runtime.Instance, description: ContentDescription) anyerror!anyopaque {
        
        return try ContentIndexImpl.call_add(instance, description);
    }

    pub fn call_getAll(instance: *runtime.Instance) anyerror!anyopaque {
        return try ContentIndexImpl.call_getAll(instance);
    }

};
