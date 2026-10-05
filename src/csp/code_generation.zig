//! CSP 4.4.1 EnsureCSPDoesNotBlockStringCompilation, steps 3-6, and 4.5.1
//! EnsureCSPDoesNotBlockWasmByteCompilation, over a global's CSP list: the
//! per-policy part, which reads script-src - else default-src, and no other
//! fallback - for 'unsafe-eval', 'wasm-unsafe-eval' and 'trusted-types-eval',
//! reports to the global's reporter, and blocks under an enforced policy.
//!
//! 4.4.1's steps 1-2 - the Trusted Types default policy over the source - run
//! script, so they are the global's (src/html/code_generation.zig), which
//! hands the resulting sourceString here. Throwing the EvalError or the
//! WebAssembly.CompileError is the engine's, on a blocked result.
//!
//! Spec: https://w3c.github.io/webappsec-csp/#can-compile-strings
//! Spec: https://w3c.github.io/webappsec-csp/#can-compile-wasm-bytes

const std = @import("std");
const types = @import("types.zig");
const violation_events = @import("violation_events.zig");
const require_trusted_types = @import("directives/require_trusted_types.zig");

pub const Result = enum { allowed, blocked };

/// The directive both algorithms read (4.4.1 steps 5.1-5.2, 4.5.1 steps
/// 3.1-3.2): "If policy contains a directive whose name is "script-src",
/// then set source-list to that directive's value. Otherwise if policy
/// contains a directive whose name is "default-src", then set source-list
/// to that directive's value."
fn sourceListDirective(policy: *const types.Policy) ?*const types.Directive {
    if (policy.getDirective("script-src")) |directive| return directive;
    return policy.getDirective("default-src");
}

/// 4.4.1 steps 3-6 for `csp_list`, the realm's global's, with
/// `source_string` - the codeString, after steps 1-2. Every violation goes
/// to `reporter` (null: none is reported, a global with no reporter).
pub fn ensureDoesNotBlockStringCompilation(
    csp_list: *const types.CSPList,
    source_string: []const u8,
    reporter: ?violation_events.Reporter,
) Result {
    // 5.3.1. "Let trustedTypesRequired be the result of executing does sink
    // type require trusted types?, with realm, 'script', and false." It
    // reads the same list for every policy: once.
    const trusted_types_required = require_trusted_types.doesSinkTypeRequireTrustedTypes(csp_list, require_trusted_types.script_sink_group, false);
    // 3. Let result be "Allowed".
    var result: Result = .allowed;
    // 5. For each policy of global's CSP list's policies:
    for (csp_list.policies.items) |*policy| {
        // 5.1-5.2. source-list: script-src's value, else default-src's.
        const directive = sourceListDirective(policy) orelse continue;
        // 5.3.2. "If trustedTypesRequired is true and source-list contains a
        // source expression which is an ASCII case-insensitive match for the
        // string "'trusted-types-eval'", then skip the following steps."
        if (trusted_types_required and directive.value.contains(.keyword_trusted_types_eval)) continue;
        // 5.3.3. 'unsafe-eval' skips them too.
        if (directive.value.contains(.keyword_unsafe_eval)) continue;
        // 5.3.4-5.3.7. A violation of "script-src" - whichever directive
        // the list came from - its resource "eval", its sample the first 40
        // characters of sourceString under 'report-sample', reported.
        if (reporter) |r| r.reportViolation(&.{
            .policy = policy,
            .effective_directive = "script-src",
            .resource = .eval,
            .sample = violation_events.sampleFor(directive, source_string),
        });
        // 5.3.8. An enforced policy blocks.
        if (policy.disposition == .enforce) result = .blocked;
    }
    // 6. "If result is "Blocked", throw an EvalError exception": the
    // caller's.
    return result;
}

/// 4.5.1 for `csp_list`, the realm's global's. Every violation goes to
/// `reporter`.
pub fn ensureDoesNotBlockWasmByteCompilation(csp_list: *const types.CSPList, reporter: ?violation_events.Reporter) Result {
    // 2. Let result be "Allowed".
    var result: Result = .allowed;
    // 3. For each policy of global's CSP list's policies:
    for (csp_list.policies.items) |*policy| {
        // 3.1-3.2. source-list: script-src's value, else default-src's.
        const directive = sourceListDirective(policy) orelse continue;
        // 3.3. Neither 'unsafe-eval' nor 'wasm-unsafe-eval':
        if (directive.value.contains(.keyword_unsafe_eval) or directive.value.contains(.keyword_wasm_unsafe_eval)) continue;
        // 3.3.1-3.3.3. A violation of "script-src", its resource
        // "wasm-eval", reported.
        if (reporter) |r| r.reportViolation(&.{
            .policy = policy,
            .effective_directive = "script-src",
            .resource = .wasm_eval,
        });
        // 3.3.4. An enforced policy blocks.
        if (policy.disposition == .enforce) result = .blocked;
    }
    // 4. "If result is "Blocked", throw a WebAssembly.CompileError
    // exception": the caller's.
    return result;
}

const testing = std.testing;
const parsing = @import("parsing.zig");

/// What a test reporter saw.
const Seen = struct {
    count: usize = 0,
    directive: []const u8 = "",
    resource: violation_events.Resource = .@"inline",
    sample: [64]u8 = undefined,
    sample_len: usize = 0,
    disposition: types.PolicyDisposition = .enforce,

    fn reporter(self: *Seen) violation_events.Reporter {
        return .{ .context = self, .report = &record };
    }

    fn record(context: *anyopaque, violation: *const violation_events.Violation) void {
        const self: *Seen = @ptrCast(@alignCast(context));
        self.count += 1;
        self.directive = violation.effective_directive;
        self.resource = violation.resource;
        self.disposition = violation.policy.disposition;
        self.sample_len = @min(violation.sample.len, self.sample.len);
        @memcpy(self.sample[0..self.sample_len], violation.sample[0..self.sample_len]);
    }
};

fn listOf(policies: []const struct { []const u8, types.PolicyDisposition }) !types.CSPList {
    var list = types.CSPList.init(testing.allocator);
    errdefer list.deinit();
    for (policies) |p| try list.append(try parsing.parseSerializedCSP(testing.allocator, p[0], .header, p[1]));
    return list;
}

test "4.4.1: script-src without 'unsafe-eval' blocks and reports script-src with resource eval; 'unsafe-eval' allows" {
    var blocking = try listOf(&.{.{ "script-src 'self' 'unsafe-inline'", .enforce }});
    defer blocking.deinit();
    var seen: Seen = .{};
    try testing.expectEqual(Result.blocked, ensureDoesNotBlockStringCompilation(&blocking, "evalRan = true", seen.reporter()));
    try testing.expectEqual(@as(usize, 1), seen.count);
    try testing.expectEqualStrings("script-src", seen.directive);
    try testing.expectEqual(violation_events.Resource.eval, seen.resource);
    try testing.expectEqual(@as(usize, 0), seen.sample_len);

    var allowing = try listOf(&.{.{ "script-src 'self' 'UNSAFE-EVAL'", .enforce }});
    defer allowing.deinit();
    var none: Seen = .{};
    try testing.expectEqual(Result.allowed, ensureDoesNotBlockStringCompilation(&allowing, "1", none.reporter()));
    try testing.expectEqual(@as(usize, 0), none.count);
}

test "4.4.1: default-src stands in for a missing script-src, and only it; the violation is still script-src's" {
    var default_src = try listOf(&.{.{ "default-src 'self' 'report-sample'", .enforce }});
    defer default_src.deinit();
    var seen: Seen = .{};
    try testing.expectEqual(Result.blocked, ensureDoesNotBlockStringCompilation(&default_src, "alert(1)", seen.reporter()));
    try testing.expectEqualStrings("script-src", seen.directive);
    try testing.expectEqualStrings("alert(1)", seen.sample[0..seen.sample_len]);

    // script-src-elem is no source list here: nothing restricts eval.
    var elem = try listOf(&.{.{ "script-src-elem 'self'; img-src 'none'", .enforce }});
    defer elem.deinit();
    var none: Seen = .{};
    try testing.expectEqual(Result.allowed, ensureDoesNotBlockStringCompilation(&elem, "1", none.reporter()));
    try testing.expectEqual(@as(usize, 0), none.count);

    // script-src wins over default-src.
    var both = try listOf(&.{.{ "default-src 'unsafe-eval'; script-src 'self'", .enforce }});
    defer both.deinit();
    try testing.expectEqual(Result.blocked, ensureDoesNotBlockStringCompilation(&both, "1", null));
}

test "4.4.1: a monitored policy reports and allows; the sample is the first 40 characters under 'report-sample'" {
    var report_only = try listOf(&.{.{ "script-src 'none' 'report-sample'", .report }});
    defer report_only.deinit();
    var seen: Seen = .{};
    const source = "0123456789012345678901234567890123456789-past-forty";
    try testing.expectEqual(Result.allowed, ensureDoesNotBlockStringCompilation(&report_only, source, seen.reporter()));
    try testing.expectEqual(@as(usize, 1), seen.count);
    try testing.expectEqual(types.PolicyDisposition.report, seen.disposition);
    try testing.expectEqualStrings(source[0..40], seen.sample[0..seen.sample_len]);
}

test "4.4.1: 'trusted-types-eval' allows only while Trusted Types are required by an enforced policy" {
    var required = try listOf(&.{.{ "script-src 'self' 'trusted-types-eval'; require-trusted-types-for 'script'", .enforce }});
    defer required.deinit();
    try testing.expectEqual(Result.allowed, ensureDoesNotBlockStringCompilation(&required, "1", null));

    var not_required = try listOf(&.{.{ "script-src 'self' 'trusted-types-eval'", .enforce }});
    defer not_required.deinit();
    try testing.expectEqual(Result.blocked, ensureDoesNotBlockStringCompilation(&not_required, "1", null));

    // Required only by a report-only policy: "false" excludes it.
    var report_only_requirement = try listOf(&.{
        .{ "script-src 'self' 'trusted-types-eval'", .enforce },
        .{ "require-trusted-types-for 'script'", .report },
    });
    defer report_only_requirement.deinit();
    try testing.expectEqual(Result.blocked, ensureDoesNotBlockStringCompilation(&report_only_requirement, "1", null));
}

test "4.5.1: 'unsafe-eval' or 'wasm-unsafe-eval' allows; otherwise script-src reports wasm-eval and an enforced policy blocks" {
    var blocking = try listOf(&.{.{ "default-src 'self' 'unsafe-inline'", .enforce }});
    defer blocking.deinit();
    var seen: Seen = .{};
    try testing.expectEqual(Result.blocked, ensureDoesNotBlockWasmByteCompilation(&blocking, seen.reporter()));
    try testing.expectEqualStrings("script-src", seen.directive);
    try testing.expectEqual(violation_events.Resource.wasm_eval, seen.resource);

    var wasm = try listOf(&.{.{ "script-src 'wasm-unsafe-eval'", .enforce }});
    defer wasm.deinit();
    try testing.expectEqual(Result.allowed, ensureDoesNotBlockWasmByteCompilation(&wasm, null));
    var eval = try listOf(&.{.{ "script-src 'unsafe-eval'", .enforce }});
    defer eval.deinit();
    try testing.expectEqual(Result.allowed, ensureDoesNotBlockWasmByteCompilation(&eval, null));
    // 'wasm-unsafe-eval' does not allow strings.
    try testing.expectEqual(Result.blocked, ensureDoesNotBlockStringCompilation(&wasm, "1", null));

    var report_only = try listOf(&.{.{ "script-src 'none'", .report }});
    defer report_only.deinit();
    var monitored: Seen = .{};
    try testing.expectEqual(Result.allowed, ensureDoesNotBlockWasmByteCompilation(&report_only, monitored.reporter()));
    try testing.expectEqual(@as(usize, 1), monitored.count);
}
