//! Generated from: permissions-policy.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PermissionsPolicyViolationReportBodyImpl = @import("../impls/PermissionsPolicyViolationReportBody.zig");
const ReportBody = @import("ReportBody.zig");

pub const PermissionsPolicyViolationReportBody = struct {
    pub const Meta = struct {
        pub const name = "PermissionsPolicyViolationReportBody";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *ReportBody;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            featureId: runtime.DOMString = undefined,
            sourceFile: ?runtime.DOMString = null,
            lineNumber: ?i32 = null,
            columnNumber: ?i32 = null,
            disposition: runtime.DOMString = undefined,
            allowAttribute: ?runtime.DOMString = null,
            srcAttribute: ?runtime.DOMString = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PermissionsPolicyViolationReportBody, .{
        .deinit_fn = &deinit_wrapper,

        .get_allowAttribute = &get_allowAttribute,
        .get_columnNumber = &get_columnNumber,
        .get_disposition = &get_disposition,
        .get_featureId = &get_featureId,
        .get_lineNumber = &get_lineNumber,
        .get_sourceFile = &get_sourceFile,
        .get_srcAttribute = &get_srcAttribute,

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
        PermissionsPolicyViolationReportBodyImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PermissionsPolicyViolationReportBodyImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_featureId(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PermissionsPolicyViolationReportBodyImpl.get_featureId(state);
    }

    pub fn get_sourceFile(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PermissionsPolicyViolationReportBodyImpl.get_sourceFile(state);
    }

    pub fn get_lineNumber(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PermissionsPolicyViolationReportBodyImpl.get_lineNumber(state);
    }

    pub fn get_columnNumber(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PermissionsPolicyViolationReportBodyImpl.get_columnNumber(state);
    }

    pub fn get_disposition(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PermissionsPolicyViolationReportBodyImpl.get_disposition(state);
    }

    pub fn get_allowAttribute(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PermissionsPolicyViolationReportBodyImpl.get_allowAttribute(state);
    }

    pub fn get_srcAttribute(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PermissionsPolicyViolationReportBodyImpl.get_srcAttribute(state);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PermissionsPolicyViolationReportBodyImpl.call_toJSON(state);
    }

};
