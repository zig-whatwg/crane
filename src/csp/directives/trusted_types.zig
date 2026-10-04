//! The `trusted-types` directive (Trusted Types 4.2.2) and "should Trusted
//! Type policy creation be blocked by Content Security Policy?" (4.2.5).
//!
//!     directive-name  = "trusted-types"
//!     directive-value = serialized-tt-configuration
//!     serialized-tt-configuration = ( tt-expression *( required-ascii-whitespace tt-expression ) )
//!     tt-expression   = tt-policy-name / tt-keyword / tt-wildcard
//!     tt-wildcard     = "*"
//!     tt-policy-name  = 1*( ALPHA / DIGIT / "-" / "#" / "=" / "_" / "/" / "@" / "." / "%")
//!     tt-keyword      = "'allow-duplicates'" / "'none'"
//!
//! The directive's value is kept as the parser split it (each token's raw
//! value); a token that is no tt-expression - `*X`, `a!b` - is ignored, as an
//! invalid expression is. Keywords match ASCII case-insensitively (RFC 5234
//! terminals); policy names exactly.
//!
//! Spec: https://w3c.github.io/trusted-types/dist/spec/#should-block-create-policy

const std = @import("std");
const types = @import("../types.zig");
const violation_events = @import("../violation_events.zig");

pub const directive_name = "trusted-types";

pub const Result = enum { allowed, blocked };

/// A tt-expression, or null for a token that is none.
pub const Expression = union(enum) {
    policy_name: []const u8,
    wildcard,
    none,
    allow_duplicates,
};

/// The tt-expression `token` is, if any.
pub fn parseExpression(token: []const u8) ?Expression {
    if (std.mem.eql(u8, token, "*")) return .wildcard;
    if (std.ascii.eqlIgnoreCase(token, "'none'")) return .none;
    if (std.ascii.eqlIgnoreCase(token, "'allow-duplicates'")) return .allow_duplicates;
    if (isPolicyName(token)) return .{ .policy_name = token };
    return null;
}

/// Whether `token` is a tt-policy-name.
pub fn isPolicyName(token: []const u8) bool {
    if (token.len == 0) return false;
    for (token) |c| {
        const ok = std.ascii.isAlphanumeric(c) or switch (c) {
            '-', '#', '=', '_', '/', '@', '.', '%' => true,
            else => false,
        };
        if (!ok) return false;
    }
    return true;
}

/// What a `trusted-types` directive's value says, its invalid tokens
/// ignored.
const Configuration = struct {
    names: bool = false,
    wildcard: bool = false,
    none: bool = false,
    allow_duplicates: bool = false,

    fn of(directive: *const types.Directive) Configuration {
        var config: Configuration = .{};
        for (directive.value.expressions.items) |expression| {
            switch (parseExpression(expression.raw_value) orelse continue) {
                .policy_name => config.names = true,
                .wildcard => config.wildcard = true,
                .none => config.none = true,
                .allow_duplicates => config.allow_duplicates = true,
            }
        }
        return config;
    }

    /// 4.2.5 step 2.4: "directive's value only contains a tt-keyword which
    /// is a match for a value 'none'".
    fn onlyNone(self: Configuration) bool {
        return self.none and !self.names and !self.wildcard and !self.allow_duplicates;
    }
};

/// Whether `directive`'s value contains the tt-policy-name `name`.
fn containsPolicyName(directive: *const types.Directive, name: []const u8) bool {
    for (directive.value.expressions.items) |expression| {
        const parsed = parseExpression(expression.raw_value) orelse continue;
        if (parsed == .policy_name and std.mem.eql(u8, parsed.policy_name, name)) return true;
    }
    return false;
}

/// 4.2.5 "Should Trusted Type policy creation be blocked by Content Security
/// Policy?", given the global's CSP list, the policy name and the factory's
/// created policy names. Each violation goes to `reporter` (CSP 5.5); a null
/// reporter reports nothing.
pub fn shouldPolicyCreationBeBlocked(
    csp_list: *const types.CSPList,
    policy_name: []const u8,
    created_policy_names: []const []const u8,
    reporter: ?violation_events.Reporter,
) Result {
    // 1. Let result be "Allowed".
    var result: Result = .allowed;
    // 2. For each policy in global's CSP list:
    for (csp_list.policies.items) |*policy| {
        // 2.1. Let createViolation be false.
        var create_violation = false;
        // 2.2-2.3. The policy's trusted-types directive, if it has one.
        const directive = policy.getDirective(directive_name) orelse continue;
        const config = Configuration.of(directive);
        // 2.4. "If directive's value only contains a tt-keyword which is a
        // match for a value 'none', set createViolation to true."
        if (config.onlyNone()) create_violation = true;
        // 2.5. "If createdPolicyNames contains policyName and directive's
        // value does not contain a tt-keyword which is a match for a value
        // 'allow-duplicates', set createViolation to true."
        for (created_policy_names) |created| {
            if (std.mem.eql(u8, created, policy_name) and !config.allow_duplicates) {
                create_violation = true;
                break;
            }
        }
        // 2.6. "If directive's value does not contain a tt-policy-name, which
        // value is policyName, and directive's value does not contain a
        // tt-wildcard, set createViolation to true."
        if (!config.wildcard and !containsPolicyName(directive, policy_name)) create_violation = true;
        // 2.7. "If createViolation is false, skip to the next policy."
        if (!create_violation) continue;
        // 2.8-2.11. The violation, its resource "trusted-types-policy" and
        // its sample the first 40 characters of policyName, reported.
        if (reporter) |r| {
            r.reportViolation(&.{
                .policy = policy,
                .effective_directive = directive_name,
                .resource = .trusted_types_policy,
                .sample = firstCharacters(policy_name, 40),
            });
        }
        // 2.12. "If policy's disposition is "enforce", then set result to
        // "Blocked"."
        if (policy.disposition == .enforce) result = .blocked;
    }
    // 3. Return result.
    return result;
}

/// "The substring of `text` containing its first `count` characters" - code
/// points of the UTF-8 text, never a split sequence. Borrowed from `text`.
pub fn firstCharacters(text: []const u8, count: usize) []const u8 {
    var it = std.unicode.Utf8View.initUnchecked(text).iterator();
    var n: usize = 0;
    while (n < count) : (n += 1) {
        _ = it.nextCodepointSlice() orelse break;
    }
    return text[0..it.i];
}

test "tt-expressions: the wildcard is exactly *, keywords any case, names from the grammar's characters" {
    try std.testing.expect(parseExpression("*").? == .wildcard);
    try std.testing.expect(parseExpression("*X") == null);
    try std.testing.expect(parseExpression("'NONE'").? == .none);
    try std.testing.expect(parseExpression("'Allow-Duplicates'").? == .allow_duplicates);
    try std.testing.expectEqualStrings("my-policy.v2", parseExpression("my-policy.v2").?.policy_name);
    try std.testing.expect(parseExpression("'other'") == null);
    try std.testing.expect(parseExpression("a,b") == null);
}
