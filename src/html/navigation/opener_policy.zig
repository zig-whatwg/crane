//! HTML 7.1.3's decisions over opener policies: "match opener policy
//! values", the browsing context group switch checks (7.1.3.2), and
//! "enforce a response's opener policy" - pure functions of the policies and
//! origins, so the navigation code that reads them from documents and
//! responses stays thin, and the decision table is tested whole.
//!
//! Origins are serialized ("scheme://host[:port]", "null" when opaque): two
//! are the same origin when they are equal tuples. A serialized opaque
//! origin cannot say which opaque origin it was, so it is same origin with
//! nothing - which only ever asks for a switch, never avoids one.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#cross-origin-opener-policies

const std = @import("std");
const fetch = @import("fetch");

pub const Value = fetch.internal.cross_origin_policies.OpenerPolicyValue;
pub const OpenerPolicy = fetch.internal.cross_origin_policies.OpenerPolicy;

/// HTML "same origin" for two serialized origins.
fn sameOrigin(a: []const u8, b: []const u8) bool {
    if (std.mem.eql(u8, a, "null") or a.len == 0) return false;
    return std.mem.eql(u8, a, b);
}

/// HTML "match opener policy values".
pub fn match(document_coop: Value, document_origin: []const u8, response_coop: Value, response_origin: []const u8) bool {
    // 1. Both "unsafe-none": true.
    if (document_coop == .unsafe_none and response_coop == .unsafe_none) return true;
    // 2. Either "unsafe-none": false.
    if (document_coop == .unsafe_none or response_coop == .unsafe_none) return false;
    // 3. The same value and same origin: true.
    if (document_coop == response_coop and sameOrigin(document_origin, response_origin)) return true;
    // 4. Return false.
    return false;
}

/// HTML "check if popup COOP values require a browsing context group
/// switch".
pub fn popupRequiresSwitch(response_origin: []const u8, active_origin: []const u8, response_coop: Value, active_coop: Value) bool {
    // 1. A response with "noopener-allow-popups": true.
    if (response_coop == .noopener_allow_popups) return true;
    // 2. An opener allowing popups, and a response with "unsafe-none":
    // false.
    if ((active_coop == .same_origin_allow_popups or active_coop == .noopener_allow_popups) and response_coop == .unsafe_none) return false;
    // 3. Matching values: false.
    if (match(active_coop, active_origin, response_coop, response_origin)) return false;
    // 4. Return true.
    return true;
}

/// HTML "check if COOP values require a browsing context group switch".
pub fn requiresSwitch(is_initial_about_blank: bool, response_origin: []const u8, active_origin: []const u8, response_coop: Value, active_coop: Value) bool {
    // 1. From the initial about:blank document: the popup rules.
    if (is_initial_about_blank) return popupRequiresSwitch(response_origin, active_origin, response_coop, active_coop);
    // 2. A non-popup navigation: matching values need no switch.
    if (match(active_coop, active_origin, response_coop, response_origin)) return false;
    // 3. Return true.
    return true;
}

/// HTML "check if enforcing report-only COOP would require a browsing
/// context group switch".
pub fn reportOnlyRequiresSwitch(is_initial_about_blank: bool, response_origin: []const u8, active_origin: []const u8, response: OpenerPolicy, active: OpenerPolicy) bool {
    // 1. Matching report-only values: false.
    if (!requiresSwitch(is_initial_about_blank, response_origin, active_origin, response.report_only_value, active.report_only_value)) return false;
    // 2. The response's enforced value against the active report-only one.
    if (requiresSwitch(is_initial_about_blank, response_origin, active_origin, response.value, active.report_only_value)) return true;
    // 3. The response's report-only value against the active enforced one.
    if (requiresSwitch(is_initial_about_blank, response_origin, active_origin, response.report_only_value, active.value)) return true;
    // 4. Return false.
    return false;
}

/// HTML "opener policy enforcement result", the parts its decisions read:
/// the URL and the opener policy are the caller's, borrowed for as long as
/// it keeps the result.
pub const EnforcementResult = struct {
    needs_switch: bool = false,
    would_need_switch_due_to_report_only: bool = false,
    /// The origin (serialized) of the document or response it describes.
    origin: []const u8,
    /// Its opener policy's value and report-only value.
    policy: OpenerPolicy,
    current_context_is_navigation_source: bool = false,
};

/// What "enforce a response's opener policy" asks its caller to report:
/// steps 4.2 and 5.2 queue violation reports when the browsing context's
/// group holds another browsing context.
pub const Reports = struct {
    /// Step 4.2: "enforce" reports, to and from the response.
    enforce: bool = false,
    /// Step 5.2: "reporting" reports.
    reporting: bool = false,
};

/// HTML "enforce a response's opener policy" for a navigable's active
/// browsing context, given whether its active document is the initial
/// about:blank (`is_initial_about_blank`) and whether its group holds other
/// browsing contexts (`group_has_others`, for the reports), the response's
/// origin and opener policy, and the current enforcement result. Returns the
/// new result; `reports` says which violation reports steps 4.2 and 5.2
/// queue (the caller queues them). Step 3 - the browsing context's initial
/// URL - is the caller's.
pub fn enforce(is_initial_about_blank: bool, group_has_others: bool, response_origin: []const u8, response_coop: OpenerPolicy, current: EnforcementResult, reports: *Reports) EnforcementResult {
    // 1. A new result, keeping the current one's switch flags.
    var result: EnforcementResult = .{
        .needs_switch = current.needs_switch,
        .would_need_switch_due_to_report_only = current.would_need_switch_due_to_report_only,
        .origin = response_origin,
        .policy = response_coop,
        .current_context_is_navigation_source = true,
    };
    // 4. The enforced values require a switch:
    if (requiresSwitch(is_initial_about_blank, response_origin, current.origin, response_coop.value, current.policy.value)) {
        // 4.1.
        result.needs_switch = true;
        // 4.2. Reports, when the group holds another browsing context.
        if (group_has_others) reports.enforce = true;
    }
    // 5. The report-only values would require one:
    if (reportOnlyRequiresSwitch(is_initial_about_blank, response_origin, current.origin, response_coop, current.policy)) {
        // 5.1.
        result.would_need_switch_due_to_report_only = true;
        // 5.2.
        if (group_has_others) reports.reporting = true;
    }
    // 6. Return the new result.
    return result;
}
