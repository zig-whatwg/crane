//! WebIDL dictionary: SummarizerSummarizeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const SummarizerSummarizeOptions = struct {
    signal: ?*runtime.Instance = null,
    context: ?runtime.DOMString = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "signal", "AbortSignal" },
    };
};
