//! Browser-majority parsing of a malformed Referrer-Policy fallback member.
const std = @import("std");
const policy = @import("fetch").referrer_policy.policy;

test "referrer header: an unparsable member preserves an earlier valid policy" {
    try std.testing.expectEqual(policy.ReferrerPolicy.origin, policy.parseReferrerPolicyHeader("origin, origin no-referrer").?);
    try std.testing.expectEqual(@as(?policy.ReferrerPolicy, null), policy.parseReferrerPolicyHeader("unknown, another-unknown"));
}
