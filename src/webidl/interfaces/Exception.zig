//! Generated from: wasm-js-api.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ExceptionImpl = @import("impls").Exception;
const (DOMString or undefined) = @import("interfaces").(DOMString or undefined);
const ExceptionOptions = @import("dictionaries").ExceptionOptions;
const Tag = @import("interfaces").Tag;

pub const Exception = struct {
    pub const Meta = struct {
        pub const name = "Exception";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "LegacyNamespace", .value = .{ .identifier = "WebAssembly" } },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "Worklet" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .Worklet = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            stack: (DOMString or undefined) = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Exception, .{
        .deinit_fn = &deinit_wrapper,

        .get_stack = &get_stack,

        .call_getArg = &call_getArg,
        .call_is = &call_is,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ExceptionImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ExceptionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, exceptionTag: Tag, payload: anyopaque, options: ExceptionOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try ExceptionImpl.constructor(instance, exceptionTag, payload, options);
        
        return instance;
    }

    pub fn get_stack(instance: *runtime.Instance) anyerror!anyopaque {
        return try ExceptionImpl.get_stack(instance);
    }

    pub fn call_is(instance: *runtime.Instance, exceptionTag: Tag) anyerror!bool {
        
        return try ExceptionImpl.call_is(instance, exceptionTag);
    }

    pub fn call_getArg(instance: *runtime.Instance, index: u32) anyerror!anyopaque {
        // [EnforceRange] on index
        if (!runtime.isInRange(index)) return error.TypeError;
        
        return try ExceptionImpl.call_getArg(instance, index);
    }

};
