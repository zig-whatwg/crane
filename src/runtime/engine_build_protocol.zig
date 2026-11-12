//! THE BUILD SIDE OF THE ENGINE PROTOCOL (docs/engine-protocol.md, 7b).
//!
//! An engine adapter's build options are declared by the adapter, in a build
//! file beside its code - `engines/<engine>/engine_build.zig` - and never by
//! the root build.zig (the user, 2026-11-12: "I don't want any of the v8 code
//! in build.zig, the valid flags should be in the js engine protocol"). This
//! file is the protocol's part: the list of adapters that have a build file,
//! and the one function the root build.zig calls. The root build names no
//! adapter and no adapter's option.
//!
//! What an adapter's build file exports:
//!
//!   pub const Options = struct { ... };       // what the command line gave
//!   pub fn declareOptions(b: *std.Build, target: std.Build.ResolvedTarget) Options
//!   pub fn apply(options: Options, adapter_options: *std.Build.Step.Options) void
//!
//! Run by `zig build`'s configure step, not compiled into Crane: std only,
//! and nothing is read from the machine.
//!
//! (The list names an adapter's directory, so tools/lint_engine_boundary.zig
//! exempts this one file: it is where the build side meets the adapters.)

const std = @import("std");

/// The adapters that have a build file, by their `-Dengine` name. An adapter
/// with no build options has no row.
pub const adapters = .{
    .v8 = @import("engines/v8/engine_build.zig"),
};

/// The options module of the build's engine adapter: the adapter named
/// `engine` declares its `-D` options and puts their values here; only the
/// engine adapter's module imports it, as "adapter_options". An adapter that
/// is not the build's engine is never asked, so its options are not declared,
/// and the configure step refuses them by itself as it refuses any `-D`
/// nothing declared.
pub fn adapterOptions(b: *std.Build, target: std.Build.ResolvedTarget, engine: []const u8) *std.Build.Step.Options {
    const adapter_options = b.addOptions();
    inline for (comptime std.meta.fieldNames(@TypeOf(adapters))) |name| {
        if (std.mem.eql(u8, engine, name)) {
            const adapter = @field(adapters, name);
            adapter.apply(adapter.declareOptions(b, target), adapter_options);
        }
    }
    return adapter_options;
}
