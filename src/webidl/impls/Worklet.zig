//! Implementation for the Worklet interface (HTML 11.3.2).
//!
//! A Worklet is made by its owner with its worklet global scope type and
//! destination type (`worklet_kind`): the CSS namespace's paintWorklet,
//! layoutWorklet and animationWorklet getters, and BaseAudioContext's
//! audioWorklet (an AudioWorklet). Its state - global scopes and added
//! modules - and addModule's steps are html.worklet_host's.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const html = @import("html");
const dom = @import("dom");
const fetch = @import("fetch");
const Worklet = interfaces.Worklet;
const worklet_host = html.worklet_host;

pub const State = Worklet.State;

/// The worklet's kind (worklet_host.Kind): given by whoever makes it.
pub const construction_args = .{"worklet_kind"};

pub const InternalState = struct {
    /// HTML 11.3.2's state of this Worklet. OWNED.
    record: *worklet_host.Worklet,
    allocator: std.mem.Allocator,
};

/// The worklet global scopes end with their document: an unloading document
/// cleanup step (HTML 11.3.3; dom.unloading_cleanup).
pub fn installHooks() void {
    dom.unloading_cleanup.install(&worklet_host.environmentEnded);
}

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    // A Worklet made without a kind (none is, today) has no state, and its
    // addModule rejects.
    if (!@hasField(@TypeOf(args), "worklet_kind")) return;
    const kind: worklet_host.Kind = args.worklet_kind;
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    internal.* = .{ .record = try worklet_host.Worklet.create(allocator, kind), .allocator = allocator };
    instance.getState(State).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.record.destroy();
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

/// Operation: addModule(moduleURL, options) - HTML 11.3.2, html.worklet_host.
pub fn call_addModule(instance: *runtime.Instance, moduleURL: runtime.USVString, options: webidl.Opt(dictionaries.WorkletOptions)) anyerror!runtime.JSValue {
    const internal = instance.getState(State).own._internal orelse return error.NotSupported;
    // WorkletOptions.credentials, "same-origin" by default.
    const given = options.getOrDefault(.{});
    const credentials: fetch.internal.CredentialsMode = switch (given.credentials orelse ._same_origin_) {
        ._omit_ => .omit,
        ._same_origin_ => .same_origin,
        ._include_ => .include,
    };
    return worklet_host.addModule(instance, internal.record, moduleURL, credentials);
}
