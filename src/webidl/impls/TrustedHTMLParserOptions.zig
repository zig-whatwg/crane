//! Implementation for the TrustedHTMLParserOptions interface (Trusted Types
//! 2.2.4).
//!
//! "TrustedHTMLParserOptions objects have an associated boolean runScripts
//! and an associated SanitizerConfig-or-null sanitizer configuration. These
//! values are set when the object is created, and will never change during
//! its lifetime." Only a policy's createParserOptions makes one (3.2 step 3,
//! through html.parser_options and dom.trusted_types); there is no
//! constructor and no member. The configuration is kept natively, as an
//! html.sanitizer.Config this object owns; the HTML parsing sinks read it
//! through dom.trusted_types' parser-options hooks.
//!
//! Spec: https://w3c.github.io/trusted-types/dist/spec/#trusted-html-parser-options

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html = @import("html");
const TrustedHTMLParserOptions = interfaces.TrustedHTMLParserOptions;

pub const State = TrustedHTMLParserOptions.State;

pub const InternalState = struct {
    run_scripts: bool = false,
    /// The sanitizer configuration, owned; null for none.
    configuration: ?html.sanitizer.Config = null,
};

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = args;
    const internal = try allocator.create(InternalState);
    internal.* = .{};
    instance.getState(StateType).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.configuration) |*configuration| configuration.deinit();
        instance.ctx.allocator.destroy(internal);
        state.own._internal = null;
    }
}

pub fn installHooks() void {
    dom.trusted_types.installParserOptions(.{ .create = &create, .value_of = &valueOf });
}

/// A new TrustedHTMLParserOptions in `realm` with `run_scripts` and a copy
/// of the configuration at `configuration` (an html.sanitizer.Config).
fn create(realm: runtime.Context, run_scripts: bool, configuration: ?*const anyopaque) anyerror!*runtime.Instance {
    const instance = try TrustedHTMLParserOptions.init(realm.allocator, realm);
    errdefer TrustedHTMLParserOptions.deinit(instance);
    const internal = instance.getState(State).own._internal.?;
    internal.run_scripts = run_scripts;
    if (configuration) |erased| internal.configuration = try html.parser_options.configFromErased(erased).clone(realm.allocator);
    return instance;
}

/// `instance`'s values when it is a TrustedHTMLParserOptions.
fn valueOf(instance: *runtime.Instance) ?dom.trusted_types.ParserOptionsValue {
    if (instance.vtable != &TrustedHTMLParserOptions.vtable) return null;
    const internal = instance.getState(State).own._internal orelse return null;
    return .{
        .run_scripts = internal.run_scripts,
        .sanitizer_configuration = if (internal.configuration) |*configuration| html.parser_options.erasedConfig(configuration) else null,
    };
}
