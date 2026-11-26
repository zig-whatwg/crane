//! WebIDL callback: EncodedAudioChunkOutputCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");

/// callback EncodedAudioChunkOutputCallback = undefined (EncodedAudioChunk output, optional EncodedAudioChunkMetadata metadata)
pub const EncodedAudioChunkOutputCallback = runtime.BorrowedCallbackFunction;

pub const Return = void;
pub const return_options: engine.ReturnOptions = .{};

pub const Args = struct {
    output: *runtime.Instance,
    metadata: webidl.Opt(dictionaries.EncodedAudioChunkMetadata) = .notPassed(),
};

/// WebIDL 3.12 "invoke a callback function" with typed arguments and return conversion.
pub fn invoke(
    realm: engine.Context,
    callback: *const engine.CallbackFunction,
    this_arg: engine.CallbackThis,
    args: Args,
    behavior: engine.ExceptionBehavior,
    allocator: std.mem.Allocator,
) engine.Error!engine.Returned(Return) {
    return engine.invokeCallbackFunctionAs(Return, return_options, realm, callback, this_arg, args, behavior, allocator);
}

/// WebIDL 3.12 "construct a callback function" with typed arguments and return conversion.
pub fn construct(
    realm: engine.Context,
    callback: *const engine.CallbackFunction,
    args: Args,
    allocator: std.mem.Allocator,
) engine.Error!engine.Returned(Return) {
    return engine.constructCallbackFunctionAs(Return, return_options, realm, callback, args, allocator);
}
