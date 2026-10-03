//! Implementation for SecurityPolicyViolationEvent interface
//!
//! Spec: https://w3c.github.io/webappsec-csp/#violation-events
//!
//! ```idl
//! [Exposed=(Window,Worker)]
//! interface SecurityPolicyViolationEvent : Event {
//!   constructor(DOMString type, optional SecurityPolicyViolationEventInit eventInitDict = {});
//!   readonly attribute USVString documentURI;
//!   readonly attribute USVString referrer;
//!   readonly attribute USVString blockedURI;
//!   readonly attribute DOMString effectiveDirective;
//!   readonly attribute DOMString violatedDirective; // historical alias of effectiveDirective
//!   readonly attribute DOMString originalPolicy;
//!   readonly attribute USVString sourceFile;
//!   readonly attribute DOMString sample;
//!   readonly attribute SecurityPolicyViolationEventDisposition disposition;
//!   readonly attribute unsigned short statusCode;
//!   readonly attribute unsigned long lineNumber;
//!   readonly attribute unsigned long columnNumber;
//! };
//! ```
//!
//! Script makes one with the constructor; the user agent fires one at a
//! violation's element or global (CSP §5.5 "report a violation",
//! src/dom/csp_violations.zig), through the same constructor.
//!
//! What the user agent's events carry, stated: sourceFile, lineNumber and
//! columnNumber are "" and 0 (a violation's source position, §2.4.1 step 2,
//! is not modelled); statusCode is 200 for a global whose URL is HTTP(S)
//! and 0 otherwise (the status of the resource a global was made from is not
//! kept); and no report goes to report-uri or report-to endpoints (§5.5
//! steps 4-5).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const event_construction = @import("dom").event_construction;
const SecurityPolicyViolationEvent = interfaces.SecurityPolicyViolationEvent;

pub const State = SecurityPolicyViolationEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// Nothing beyond the attributes, which the generated State holds.
pub const InternalState = struct {};

/// Initialize instance: the Event part (its internal state, the constructing
/// steps it installs), then this interface's attributes at their
/// dictionary defaults.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try interfaces.Event.initWithState(allocator, StateType, vtable, ctx);
    const state = instance.getState(StateType);
    state.own.documentURI = "";
    state.own.referrer = "";
    state.own.blockedURI = "";
    state.own.effectiveDirective = runtime.DOMString.initEmpty();
    state.own.violatedDirective = runtime.DOMString.initEmpty();
    state.own.originalPolicy = runtime.DOMString.initEmpty();
    state.own.sourceFile = "";
    state.own.sample = runtime.DOMString.initEmpty();
    state.own.disposition = ._enforce_;
    state.own.statusCode = 0;
    state.own.lineNumber = 0;
    state.own.columnNumber = 0;
    return instance;
}

/// Deinitialize instance: its own strings, then the Event part.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const allocator = instance.ctx.allocator;
    for ([_]*runtime.USVString{ &state.own.documentURI, &state.own.referrer, &state.own.blockedURI, &state.own.sourceFile }) |field| {
        if (field.len > 0) allocator.free(field.*);
        field.* = "";
    }
    for ([_]*typedefs.DOMString{ &state.own.effectiveDirective, &state.own.violatedDirective, &state.own.originalPolicy, &state.own.sample }) |field| {
        field.deinit(allocator);
        field.* = runtime.DOMString.initEmpty();
    }
    interfaces.Event.deinit(instance);
}

/// Constructor: DOM "inner event creation steps" with the dictionary's
/// EventInit part, then each SecurityPolicyViolationEventInit member
/// initializing the attribute of its name (strings "", disposition
/// "enforce", numbers 0 by default).
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.SecurityPolicyViolationEventInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &SecurityPolicyViolationEvent.vtable, ctx);
    errdefer deinit(instance);
    const dict: dictionaries.SecurityPolicyViolationEventInit = if (eventInitDict.was_passed) eventInitDict.value else .{ .base = .{} };
    try event_construction.innerEventCreationSteps(instance, @"type", event_construction.eventInitFrom(dict.base));
    const state = instance.getState(State);
    // Copied: the binding frees the dictionary's strings when the
    // constructor returns.
    state.own.documentURI = try copyUsv(ctx.allocator, dict.documentURI);
    state.own.referrer = try copyUsv(ctx.allocator, dict.referrer);
    state.own.blockedURI = try copyUsv(ctx.allocator, dict.blockedURI);
    state.own.sourceFile = try copyUsv(ctx.allocator, dict.sourceFile);
    if (dict.effectiveDirective) |value| state.own.effectiveDirective = try value.clone(ctx.allocator);
    if (dict.violatedDirective) |value| state.own.violatedDirective = try value.clone(ctx.allocator);
    if (dict.originalPolicy) |value| state.own.originalPolicy = try value.clone(ctx.allocator);
    if (dict.sample) |value| state.own.sample = try value.clone(ctx.allocator);
    state.own.disposition = dict.disposition orelse ._enforce_;
    state.own.statusCode = dict.statusCode orelse 0;
    state.own.lineNumber = dict.lineNumber orelse 0;
    state.own.columnNumber = dict.columnNumber orelse 0;
    return instance;
}

/// The event's own copy of a dictionary USVString member; "" when absent.
fn copyUsv(allocator: std.mem.Allocator, value: ?runtime.USVString) !runtime.USVString {
    const v = value orelse return "";
    if (v.len == 0) return "";
    return allocator.dupe(u8, v);
}

/// A USVString attribute's value for the binding, which frees what it is
/// handed: a copy.
fn usvAttribute(instance: *runtime.Instance, value: runtime.USVString) !runtime.USVString {
    if (value.len == 0) return "";
    return instance.ctx.allocator.dupe(u8, value);
}

/// Getter for documentURI
pub fn get_documentURI(instance: *runtime.Instance) anyerror!runtime.USVString {
    return usvAttribute(instance, instance.getState(State).own.documentURI);
}

/// Getter for referrer
pub fn get_referrer(instance: *runtime.Instance) anyerror!runtime.USVString {
    return usvAttribute(instance, instance.getState(State).own.referrer);
}

/// Getter for blockedURI
pub fn get_blockedURI(instance: *runtime.Instance) anyerror!runtime.USVString {
    return usvAttribute(instance, instance.getState(State).own.blockedURI);
}

/// Getter for effectiveDirective. A view of the event's own copy.
pub fn get_effectiveDirective(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned(instance.getState(State).own.effectiveDirective.asSlice());
}

/// Getter for violatedDirective ("historical alias of effectiveDirective":
/// the user agent initializes both to the same value). A view.
pub fn get_violatedDirective(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned(instance.getState(State).own.violatedDirective.asSlice());
}

/// Getter for originalPolicy. A view.
pub fn get_originalPolicy(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned(instance.getState(State).own.originalPolicy.asSlice());
}

/// Getter for sourceFile
pub fn get_sourceFile(instance: *runtime.Instance) anyerror!runtime.USVString {
    return usvAttribute(instance, instance.getState(State).own.sourceFile);
}

/// Getter for sample. A view.
pub fn get_sample(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned(instance.getState(State).own.sample.asSlice());
}

/// Getter for disposition
pub fn get_disposition(instance: *runtime.Instance) anyerror!enums.SecurityPolicyViolationEventDisposition {
    return instance.getState(State).own.disposition;
}

/// Getter for statusCode
pub fn get_statusCode(instance: *runtime.Instance) anyerror!u16 {
    return instance.getState(State).own.statusCode;
}

/// Getter for lineNumber
pub fn get_lineNumber(instance: *runtime.Instance) anyerror!u32 {
    return instance.getState(State).own.lineNumber;
}

/// Getter for columnNumber
pub fn get_columnNumber(instance: *runtime.Instance) anyerror!u32 {
    return instance.getState(State).own.columnNumber;
}
