//! Generated from: intervention-reporting.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const InterventionReportBodyImpl = @import("impls").InterventionReportBody;
const ReportBody = @import("dictionaries").ReportBody;
const unsigned long = @import("interfaces").unsigned long;
const DOMString = @import("typedefs").DOMString;

pub const InterventionReportBody = struct {
    pub const Meta = struct {
        pub const name = "InterventionReportBody";
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
            message: runtime.DOMString = undefined,
            sourceFile: ?runtime.DOMString = null,
            lineNumber: ?u32 = null,
            columnNumber: ?u32 = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(InterventionReportBody, .{
        .deinit_fn = &deinit_wrapper,

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
        
        // Initialize the instance (Impl receives full instance)
        InterventionReportBodyImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        InterventionReportBodyImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try InterventionReportBodyImpl.get_id(instance);
    }

    pub fn get_message(instance: *runtime.Instance) anyerror!DOMString {
        return try InterventionReportBodyImpl.get_message(instance);
    }

    pub fn get_sourceFile(instance: *runtime.Instance) anyerror!anyopaque {
        return try InterventionReportBodyImpl.get_sourceFile(instance);
    }

    pub fn get_lineNumber(instance: *runtime.Instance) anyerror!anyopaque {
        return try InterventionReportBodyImpl.get_lineNumber(instance);
    }

    pub fn get_columnNumber(instance: *runtime.Instance) anyerror!anyopaque {
        return try InterventionReportBodyImpl.get_columnNumber(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!anyopaque {
        return try InterventionReportBodyImpl.call_toJSON(instance);
    }

};
