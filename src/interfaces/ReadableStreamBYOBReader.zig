//! Generated from: streams.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ReadableStreamBYOBReaderImpl = @import("../impls/ReadableStreamBYOBReader.zig");
const ReadableStreamGenericReader = @import("ReadableStreamGenericReader.zig");

pub const ReadableStreamBYOBReader = struct {
    pub const Meta = struct {
        pub const name = "ReadableStreamBYOBReader";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            ReadableStreamGenericReader,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {
            closed: Promise<undefined> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ReadableStreamBYOBReader, .{
        .deinit_fn = &deinit_wrapper,

        .get_closed = &get_closed,

        .call_cancel = &call_cancel,
        .call_read = &call_read,
        .call_releaseLock = &call_releaseLock,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ReadableStreamBYOBReaderImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ReadableStreamBYOBReaderImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, stream: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try ReadableStreamBYOBReaderImpl.constructor(state, stream);
        
        return instance;
    }

    pub fn get_closed(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ReadableStreamBYOBReaderImpl.get_closed(state);
    }

    pub fn call_read(instance: *runtime.Instance, view: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ReadableStreamBYOBReaderImpl.call_read(state, view, options);
    }

    pub fn call_releaseLock(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ReadableStreamBYOBReaderImpl.call_releaseLock(state);
    }

    pub fn call_cancel(instance: *runtime.Instance, reason: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ReadableStreamBYOBReaderImpl.call_cancel(state, reason);
    }

};
