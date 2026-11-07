//! Implementation for IntegrityViolationReportBody interface
//!
//! Subresource Integrity's report body (sri_reporting.zig writes its members).
//! One of the report body interfaces of specs/supplementary/
//! reporting-interfaces.idl (the user's ruling of 2026-11-05): its members are
//! read from the native report record it was made from
//! (dom.reporting.makeBody, dom.reporting.BodyImpl).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const reporting = @import("dom").reporting;
const IntegrityViolationReportBody = interfaces.IntegrityViolationReportBody;

pub const State = IntegrityViolationReportBody.State;

const Body = reporting.BodyImpl(State);
pub const construction_args = Body.construction_args;
pub const InternalState = reporting.BodyInternal;
pub const initOwn = Body.initOwn;
pub const deinitOwn = Body.deinitOwn;

/// Getter for documentURL
pub fn get_documentURL(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try instance.ctx.allocator.dupe(u8, (try Body.fields(instance)).string("documentURL") orelse "");
}

/// Getter for blockedURL
pub fn get_blockedURL(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try instance.ctx.allocator.dupe(u8, (try Body.fields(instance)).string("blockedURL") orelse "");
}

/// Getter for destination
pub fn get_destination(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try instance.ctx.allocator.dupe(u8, (try Body.fields(instance)).string("destination") orelse "");
}

/// Getter for reportOnly
pub fn get_reportOnly(instance: *runtime.Instance) anyerror!bool {
    return (try Body.fields(instance)).boolean("reportOnly");
}

/// Operation: toJSON ([Default]: every attribute, ReportBody's none)
pub fn call_toJSON(instance: *runtime.Instance) anyerror!IntegrityViolationReportBody.IntegrityViolationReportBodyToJSON {
    const fields = try Body.fields(instance);
    return .{
        .documentURL = fields.string("documentURL") orelse "",
        .blockedURL = fields.string("blockedURL") orelse "",
        .destination = fields.string("destination") orelse "",
        .reportOnly = fields.boolean("reportOnly"),
    };
}
