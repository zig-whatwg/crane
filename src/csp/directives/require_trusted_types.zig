//! The `require-trusted-types-for` directive (Trusted Types 4.2.1), "does
//! sink type require trusted types?" (4.2.3) and "should sink type mismatch
//! violation be blocked by Content Security Policy?" (4.2.4).
//!
//!     directive-name  = "require-trusted-types-for"
//!     directive-value = trusted-types-sink-group-keyword *( required-ascii-whitespace trusted-types-sink-group-keyword)
//!     trusted-types-sink-group-keyword = "'" trusted-types-sink-group "'"
//!     trusted-types-sink-group = "script"
//!
//! A sink group is named with its quotes ("'script'"), as the algorithms
//! pass it, and matches ASCII case-insensitively (an RFC 5234 terminal).
//!
//! The pre-navigation check for `javascript:` URLs (4.2.1.1) runs the
//! default policy, so it lives with the global (src/dom/trusted_types.zig).
//!
//! Spec: https://w3c.github.io/trusted-types/dist/spec/#require-trusted-types-for-csp-directive

const std = @import("std");
const types = @import("../types.zig");
const violation_events = @import("../violation_events.zig");
const firstCharacters = @import("trusted_types.zig").firstCharacters;

pub const directive_name = "require-trusted-types-for";

/// The one sink group the spec defines, as the algorithms pass it.
pub const script_sink_group = "'script'";

pub const Result = enum { allowed, blocked };

/// The policy's require-trusted-types-for directive, if its value contains a
/// sink group matching `sink_group` (4.2.3 steps 1.1-1.3, 4.2.4 steps
/// 4.1-4.3).
fn requiringDirective(policy: *const types.Policy, sink_group: []const u8) ?*const types.Directive {
    const directive = policy.getDirective(directive_name) orelse return null;
    for (directive.value.expressions.items) |expression| {
        if (std.ascii.eqlIgnoreCase(expression.raw_value, sink_group)) return directive;
    }
    return null;
}

/// 4.2.3 "Does sink type require trusted types?", given the global's CSP
/// list.
pub fn doesSinkTypeRequireTrustedTypes(csp_list: *const types.CSPList, sink_group: []const u8, include_report_only_policies: bool) bool {
    // 1. For each policy in global's CSP list:
    for (csp_list.policies.items) |*policy| {
        // 1.1-1.3. Skip a policy without the directive, or whose value has
        // no matching sink group.
        _ = requiringDirective(policy, sink_group) orelse continue;
        // 1.4-1.5. An enforced policy requires.
        if (policy.disposition == .enforce) return true;
        // 1.6. So does a report-only one, when those are included.
        if (include_report_only_policies) return true;
    }
    // 2. Return false.
    return false;
}

/// 4.2.4 "Should sink type mismatch violation be blocked by Content Security
/// Policy?", given the global's CSP list, the sink, the sink group and the
/// source. Each violation goes to `reporter` (CSP 5.5); `allocator` builds
/// the sample for the call.
pub fn shouldSinkTypeMismatchViolationBeBlocked(
    allocator: std.mem.Allocator,
    csp_list: *const types.CSPList,
    sink: []const u8,
    sink_group: []const u8,
    source: []const u8,
    reporter: ?violation_events.Reporter,
) error{OutOfMemory}!Result {
    // 1. Let result be "Allowed".
    var result: Result = .allowed;
    // 2. Let sample be source.
    var sample = source;
    // 3. If sink is "Function", strip the anonymous function's prefix.
    if (std.mem.eql(u8, sink, "Function")) {
        const prefixes = [_][]const u8{ "function anonymous", "async function anonymous", "function* anonymous", "async function* anonymous" };
        for (prefixes) |prefix| {
            if (std.mem.startsWith(u8, sample, prefix)) {
                sample = sample[prefix.len..];
                break;
            }
        }
    }
    // 4.6-4.7: "the substring of sample, containing its first 40
    // characters", after the sink and "|" - the same for every policy.
    const violation_sample = try std.mem.concat(allocator, u8, &.{ sink, "|", firstCharacters(sample, 40) });
    defer allocator.free(violation_sample);

    // 4. For each policy in global's CSP list:
    for (csp_list.policies.items) |*policy| {
        // 4.1-4.3.
        _ = requiringDirective(policy, sink_group) orelse continue;
        // 4.4-4.8. The violation, its resource "trusted-types-sink", its
        // sample, reported.
        if (reporter) |r| {
            r.reportViolation(&.{
                .policy = policy,
                .effective_directive = directive_name,
                .resource = .trusted_types_sink,
                .sample = violation_sample,
            });
        }
        // 4.9. "If policy's disposition is "enforce", then set result to
        // "Blocked"."
        if (policy.disposition == .enforce) result = .blocked;
    }
    // 5. Return result.
    return result;
}
