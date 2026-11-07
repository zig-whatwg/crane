//! Implementation for ConnectionAllowlistViolationReport interface
//!
//! Connection Allowlists' report body (Crane makes no such report).
//! One of the report body interfaces of specs/supplementary/
//! reporting-interfaces.idl (the user's ruling of 2026-11-05): its members are
//! read from the native report record it was made from
//! (dom.reporting.makeBody, dom.reporting.BodyImpl).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const enums = @import("enums");
const engine = @import("engine");
const reporting = @import("dom").reporting;
const ConnectionAllowlistViolationReport = interfaces.ConnectionAllowlistViolationReport;

pub const State = ConnectionAllowlistViolationReport.State;

const Body = reporting.BodyImpl(State);
pub const construction_args = Body.construction_args;
pub const InternalState = reporting.BodyInternal;
pub const initOwn = Body.initOwn;
pub const deinitOwn = Body.deinitOwn;

/// Getter for url
pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try instance.ctx.allocator.dupe(u8, (try Body.fields(instance)).string("url") orelse "");
}

/// Getter for connection
pub fn get_connection(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try instance.ctx.allocator.dupe(u8, (try Body.fields(instance)).string("connection") orelse "");
}

/// Getter for allowlist
pub fn get_allowlist(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return (try engine.createFrozenArray(instance.ctx, &.{})).take();
}

/// Getter for disposition
pub fn get_disposition(instance: *runtime.Instance) anyerror!enums.ConnectionAllowlistDisposition {
    return (try Body.fields(instance)).enumeration(enums.ConnectionAllowlistDisposition, "disposition");
}

/// Operation: toJSON ([Default]: every attribute, ReportBody's none)
pub fn call_toJSON(instance: *runtime.Instance) anyerror!ConnectionAllowlistViolationReport.ConnectionAllowlistViolationReportToJSON {
    const fields = try Body.fields(instance);
    return .{
        .url = fields.string("url") orelse "",
        .connection = fields.string("connection") orelse "",
        .allowlist = (try engine.createFrozenArray(instance.ctx, &.{})).take(),
        .disposition = fields.enumeration(enums.ConnectionAllowlistDisposition, "disposition"),
    };
}
