//! Implementation for InterventionReportBody interface
//!
//! Intervention Reporting's report body (Crane makes no intervention report).
//! One of the report body interfaces of specs/supplementary/
//! reporting-interfaces.idl (the user's ruling of 2026-11-05): its members are
//! read from the native report record it was made from
//! (dom.reporting.makeBody, dom.reporting.BodyImpl).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const reporting = @import("dom").reporting;
const InterventionReportBody = interfaces.InterventionReportBody;

pub const State = InterventionReportBody.State;

const Body = reporting.BodyImpl(State);
pub const construction_args = Body.construction_args;
pub const InternalState = reporting.BodyInternal;
pub const initOwn = Body.initOwn;
pub const deinitOwn = Body.deinitOwn;

/// Getter for id
pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try Body.fields(instance)).string("id") orelse "");
}

/// Getter for message
pub fn get_message(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try Body.fields(instance)).string("message") orelse "");
}

/// Getter for sourceFile
pub fn get_sourceFile(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return if ((try Body.fields(instance)).string("sourceFile")) |value| runtime.DOMString.initInterned(value) else null;
}

/// Getter for lineNumber
pub fn get_lineNumber(instance: *runtime.Instance) anyerror!?u32 {
    return (try Body.fields(instance)).unsigned("lineNumber");
}

/// Getter for columnNumber
pub fn get_columnNumber(instance: *runtime.Instance) anyerror!?u32 {
    return (try Body.fields(instance)).unsigned("columnNumber");
}

/// Operation: toJSON ([Default]: every attribute, ReportBody's none)
pub fn call_toJSON(instance: *runtime.Instance) anyerror!InterventionReportBody.InterventionReportBodyToJSON {
    const fields = try Body.fields(instance);
    return .{
        .id = runtime.DOMString.initInterned(fields.string("id") orelse ""),
        .message = runtime.DOMString.initInterned(fields.string("message") orelse ""),
        .sourceFile = if (fields.string("sourceFile")) |value| runtime.DOMString.initInterned(value) else null,
        .lineNumber = fields.unsigned("lineNumber"),
        .columnNumber = fields.unsigned("columnNumber"),
    };
}
