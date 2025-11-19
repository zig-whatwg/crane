//! Generated from: webgpu.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUCompilationMessageImpl = @import("impls").GPUCompilationMessage;
const GPUCompilationMessageType = @import("enums").GPUCompilationMessageType;
const DOMString = @import("typedefs").DOMString;

pub const GPUCompilationMessage = struct {
    pub const Meta = struct {
        pub const name = "GPUCompilationMessage";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            message: runtime.DOMString = undefined,
            @"type": GPUCompilationMessageType = undefined,
            lineNum: u64 = undefined,
            linePos: u64 = undefined,
            offset: u64 = undefined,
            length: u64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GPUCompilationMessage, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,
        .get_lineNum = &get_lineNum,
        .get_linePos = &get_linePos,
        .get_message = &get_message,
        .get_offset = &get_offset,
        .get_type = &get_type,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return GPUCompilationMessageImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUCompilationMessageImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_message(instance: *runtime.Instance) anyerror!DOMString {
        return try GPUCompilationMessageImpl.get_message(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!GPUCompilationMessageType {
        return try GPUCompilationMessageImpl.get_type(instance);
    }

    pub fn get_lineNum(instance: *runtime.Instance) anyerror!u64 {
        return try GPUCompilationMessageImpl.get_lineNum(instance);
    }

    pub fn get_linePos(instance: *runtime.Instance) anyerror!u64 {
        return try GPUCompilationMessageImpl.get_linePos(instance);
    }

    pub fn get_offset(instance: *runtime.Instance) anyerror!u64 {
        return try GPUCompilationMessageImpl.get_offset(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u64 {
        return try GPUCompilationMessageImpl.get_length(instance);
    }

};
