//! Generated from: deprecation-reporting.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DeprecationReportBodyImpl = @import("../impls/DeprecationReportBody.zig");
const ReportBody = @import("ReportBody.zig");

pub const DeprecationReportBody = struct {
    pub const Meta = struct {
        pub const name = "DeprecationReportBody";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *ReportBody;
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
        struct {
            id: runtime.DOMString = undefined,
            anticipatedRemoval: ?anyopaque = null,
            message: runtime.DOMString = undefined,
            sourceFile: ?runtime.DOMString = null,
            lineNumber: ?u32 = null,
            columnNumber: ?u32 = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DeprecationReportBody, .{
        .deinit_fn = &deinit_wrapper,

        .get_anticipatedRemoval = &get_anticipatedRemoval,
        .get_columnNumber = &get_columnNumber,
        .get_id = &get_id,
        .get_lineNumber = &get_lineNumber,
        .get_message = &get_message,
        .get_sourceFile = &get_sourceFile,

        .call_toJSON = &call_toJSON,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        DeprecationReportBodyImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DeprecationReportBodyImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return DeprecationReportBodyImpl.get_id(state);
    }

    pub fn get_anticipatedRemoval(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeprecationReportBodyImpl.get_anticipatedRemoval(state);
    }

    pub fn get_message(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return DeprecationReportBodyImpl.get_message(state);
    }

    pub fn get_sourceFile(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeprecationReportBodyImpl.get_sourceFile(state);
    }

    pub fn get_lineNumber(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeprecationReportBodyImpl.get_lineNumber(state);
    }

    pub fn get_columnNumber(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeprecationReportBodyImpl.get_columnNumber(state);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeprecationReportBodyImpl.call_toJSON(state);
    }

};
