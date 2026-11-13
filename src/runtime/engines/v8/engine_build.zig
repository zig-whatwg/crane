//! The BUILD SIDE of the V8 adapter (docs/engine-protocol.md, 7b): the build
//! options that are V8's alone are declared here, by the adapter, and
//! nowhere in the root build.zig (the user, 2026-11-12: "I don't want any of
//! the v8 code in build.zig, the valid flags should be in the js engine
//! protocol").
//!
//! The protocol's build file (src/runtime/engine_build_protocol.zig, which
//! the root build.zig imports) lists the adapters' build files by engine
//! name and calls this interface, the same for every adapter that has a
//! build side:
//!
//!   - `declareOptions(b, target)` declares the adapter's `-D` options and
//!     returns what the command line gave; an option's default may depend on
//!     the target. An adapter that is not the build's engine is never asked,
//!     so its options do not exist in that build: `zig build` itself refuses
//!     a `-D` nothing declared.
//!   - `apply(options, adapter_options)` puts the values in the adapter's own
//!     options module - `@import("adapter_options")`, which only the engine
//!     adapter's module imports - never in the `build_options` every module
//!     shares.
//!
//! A build file is run by `zig build`'s configure step, not compiled into
//! Crane: it imports std alone and reads nothing from the machine.
//!
//! Still in the root build.zig, to move here (lane build1): which V8 archive
//! is linked (-Dv8, -Dv8-build), -Djitless, -Dv8-compilation-cache,
//! -Dv8-extra-flags and the V8 link lines.

const std = @import("std");

/// What the command line gave the adapter's options.
pub const Options = struct {
    /// `-Dv8-young-generation-mb`: megabytes of the WHOLE young generation of
    /// each isolate; 0 is V8's own sizing; null, not given, is the adapter's
    /// default (young_generation.zig `default_mb`, which says what the value
    /// means and how it is applied).
    young_generation_mb: ?u32,
    /// `-Dv8-navigation-collection-mb`: how many megabytes V8's heap must
    /// hold for the collection after a main frame's navigation; 0 is never;
    /// null, not given, is the adapter's default (navigation_collection.zig,
    /// which says what it is and why).
    navigation_collection_mb: ?u32,
    /// `-Dv8-wrapper-trace-check`: compile in the node wrapper walk's oracle
    /// (node_wrappers.zig `checkWalk`, the wrapper redesign's P5): in every
    /// major collection's weak processing the trees every kept node wrapper
    /// keeps are walked unpruned, each wrapper they hold must have been kept
    /// and each kept wrapper's node reached by the walk. A diagnosis build's
    /// option: it costs a walk of every live tree per collection. Not given:
    /// off.
    wrapper_trace_check: bool,
};

/// Declare the V8 adapter's build options. `target`: what the build is for -
/// no option here defaults from it yet (-Djitless will, when it moves here).
pub fn declareOptions(b: *std.Build, target: std.Build.ResolvedTarget) Options {
    _ = target;
    return .{
        .young_generation_mb = b.option(
            u32,
            "v8-young-generation-mb",
            "V8: the most memory each isolate's young generation takes at rest, in MB of the WHOLE young generation: 24 = 8 MB semispaces (the default: src/runtime/engines/v8/young_generation.zig default_mb), 48 = 16 MB, 96 = 32 MB, 0 = V8's own sizing (32 MB semispaces, Chrome's on desktop: for a desktop build)",
        ),
        .navigation_collection_mb = b.option(
            u32,
            "v8-navigation-collection-mb",
            "V8: after a main frame's navigation, collect the page that was left when V8's heap holds at least this many MB (default: 16 with a limited young generation, never with V8's own sizing, -Dv8-young-generation-mb=0); 0 = never",
        ),
        .wrapper_trace_check = b.option(
            bool,
            "v8-wrapper-trace-check",
            "V8: check the node wrapper walk in every major collection (the wrapper redesign's oracle; logs wrapper-trace-check errors, costs a walk of every live tree per collection)",
        ) orelse false,
    };
}

/// Put `options` in the adapter's own options module.
pub fn apply(options: Options, adapter_options: *std.Build.Step.Options) void {
    adapter_options.addOption(?u32, "young_generation_mb", options.young_generation_mb);
    adapter_options.addOption(?u32, "navigation_collection_mb", options.navigation_collection_mb);
    adapter_options.addOption(bool, "wrapper_trace_check", options.wrapper_trace_check);
}
