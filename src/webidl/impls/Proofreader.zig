//! Implementation for Proofreader interface

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const mixins = @import("mixins");
const Proofreader = interfaces.Proofreader;

pub const State = Proofreader.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

// Construction and destruction: the generated interface's chain runs the
// parent interface's steps. For state of this interface's own, define
//
//   pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void
//   pub fn deinitOwn(instance: *runtime.Instance) void
//
// (run after and before the parent's), and list what it is given at
// construction in `pub const construction_args = .{"name"};`.

/// Getter for includeCorrectionTypes
pub fn get_includeCorrectionTypes(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for includeCorrectionExplanations
pub fn get_includeCorrectionExplanations(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for expectedInputLanguages
pub fn get_expectedInputLanguages(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    return null;
}

/// Getter for correctionExplanationLanguage
pub fn get_correctionExplanationLanguage(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Operation: proofread
pub fn call_proofread(instance: *runtime.Instance, input: runtime.DOMString, options: webidl.Opt(dictionaries.ProofreaderProofreadOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: create
pub fn call_static_create(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ProofreaderCreateOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: availability
pub fn call_static_availability(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ProofreaderCreateCoreOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}
