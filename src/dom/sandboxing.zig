//! HTML 7.1.5 Sandboxing: the sandboxing flag set, "parse a sandboxing
//! directive", a CSP list's CSP-derived sandboxing flags, and "determine the
//! creation sandboxing flags".
//!
//! A flag that is SET restricts: an empty set is a document that is not
//! sandboxed at all. That is the spec's shape, and it makes every combination
//! the spec asks for a union - a navigation's final flags are its target's
//! creation flags united with its response's CSP-derived ones, a child
//! navigable's creation flags are its iframe's flags united with its
//! container document's active flags - where an "allow" shape needs an
//! intersection that is easy to get backwards.
//!
//! Every Document has an active sandboxing flag set, fixed when "create and
//! initialize a Document object" makes it (Document's `sandboxing_flags`
//! construction argument) and read through `dom.document_scripts`. An
//! iframe's sandbox attribute only parses into the element's iframe
//! sandboxing flag set; it reaches a document when the iframe next navigates.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#sandboxing

const std = @import("std");
const csp = @import("csp");

/// HTML's sandboxing flag set: each field is one flag, set (true) when the
/// restriction applies.
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#sandboxing-flag-set
pub const SandboxingFlagSet = packed struct(u32) {
    /// The sandboxed navigation browsing context flag.
    navigation: bool = false,
    /// The sandboxed auxiliary navigation browsing context flag.
    auxiliary_navigation: bool = false,
    /// The sandboxed top-level navigation without user activation browsing
    /// context flag.
    top_level_navigation_without_user_activation: bool = false,
    /// The sandboxed top-level navigation with user activation browsing
    /// context flag.
    top_level_navigation_with_user_activation: bool = false,
    /// The sandboxed origin browsing context flag.
    origin: bool = false,
    /// The sandboxed forms browsing context flag.
    forms: bool = false,
    /// The sandboxed pointer lock browsing context flag.
    pointer_lock: bool = false,
    /// The sandboxed scripts browsing context flag.
    scripts: bool = false,
    /// The sandboxed automatic features browsing context flag.
    automatic_features: bool = false,
    /// The sandboxed document.domain browsing context flag.
    document_domain: bool = false,
    /// The sandbox propagates to auxiliary browsing contexts flag.
    propagates_to_auxiliary: bool = false,
    /// The sandboxed modals flag.
    modals: bool = false,
    /// The sandboxed orientation lock browsing context flag.
    orientation_lock: bool = false,
    /// The sandboxed presentation browsing context flag.
    presentation: bool = false,
    /// The sandboxed downloads browsing context flag.
    downloads: bool = false,
    /// The sandboxed custom protocols navigation browsing context flag.
    custom_protocols_navigation: bool = false,
    /// The Storage Access API's sandboxed storage access by user activation
    /// flag (the allow-storage-access-by-user-activation keyword).
    storage_access_by_user_activation: bool = false,
    _padding: u15 = 0,

    /// The empty set: nothing sandboxed.
    pub const empty: SandboxingFlagSet = .{};

    /// Infra "union".
    pub fn unionWith(self: SandboxingFlagSet, other: SandboxingFlagSet) SandboxingFlagSet {
        return @bitCast(@as(u32, @bitCast(self)) | @as(u32, @bitCast(other)));
    }

    /// Whether no flag is set.
    pub fn isEmpty(self: SandboxingFlagSet) bool {
        return @as(u32, @bitCast(self)) == 0;
    }

    pub fn eql(self: SandboxingFlagSet, other: SandboxingFlagSet) bool {
        return @as(u32, @bitCast(self)) == @as(u32, @bitCast(other));
    }
};

/// The keywords the iframe sandbox attribute supports (its DOMTokenList's
/// supported tokens), in ASCII order.
/// Spec: https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-sandbox
pub const supported_tokens = [_][]const u8{
    "allow-downloads",
    "allow-forms",
    "allow-modals",
    "allow-orientation-lock",
    "allow-pointer-lock",
    "allow-popups",
    "allow-popups-to-escape-sandbox",
    "allow-presentation",
    "allow-same-origin",
    "allow-scripts",
    "allow-storage-access-by-user-activation",
    "allow-top-navigation",
    "allow-top-navigation-by-user-activation",
    "allow-top-navigation-to-custom-protocols",
};

/// The allow- keywords a token list holds. The attribute's keywords are
/// ASCII case-insensitive (it is an "unordered set of unique space-separated
/// tokens, each of which is an ASCII case-insensitive match" for one of
/// them); unknown tokens are ignored.
const Allowed = struct {
    downloads: bool = false,
    forms: bool = false,
    modals: bool = false,
    orientation_lock: bool = false,
    pointer_lock: bool = false,
    popups: bool = false,
    popups_to_escape_sandbox: bool = false,
    presentation: bool = false,
    same_origin: bool = false,
    scripts: bool = false,
    storage_access_by_user_activation: bool = false,
    top_navigation: bool = false,
    top_navigation_by_user_activation: bool = false,
    top_navigation_to_custom_protocols: bool = false,

    fn note(self: *Allowed, token: []const u8) void {
        inline for (@typeInfo(Allowed).@"struct".fields) |field| {
            const keyword = comptime keywordOf(field.name);
            if (std.ascii.eqlIgnoreCase(token, keyword)) @field(self, field.name) = true;
        }
    }

    fn keywordOf(comptime field: []const u8) []const u8 {
        comptime {
            var name: [field.len]u8 = undefined;
            for (field, 0..) |c, i| name[i] = if (c == '_') '-' else c;
            const final = name;
            return "allow-" ++ &final;
        }
    }
};

/// HTML "parse a sandboxing directive" for `input` - an iframe's sandbox
/// attribute value, or a CSP sandbox directive's tokens joined by spaces.
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#parse-a-sandboxing-directive
pub fn parseSandboxingDirective(input: []const u8) SandboxingFlagSet {
    // 1. "Split input on ASCII whitespace, to obtain tokens."
    var allowed: Allowed = .{};
    var tokens = std.mem.tokenizeAny(u8, input, "\t\n\x0c\r ");
    while (tokens.next()) |token| allowed.note(token);
    return fromAllowed(allowed);
}

/// "Parse a sandboxing directive" for a token list already split.
pub fn parseSandboxingTokens(tokens: []const []const u8) SandboxingFlagSet {
    var allowed: Allowed = .{};
    for (tokens) |token| allowed.note(token);
    return fromAllowed(allowed);
}

/// Steps 2-3 of "parse a sandboxing directive": the flags `allowed` leaves
/// set.
fn fromAllowed(allowed: Allowed) SandboxingFlagSet {
    return .{
        // "The sandboxed navigation browsing context flag" - always.
        .navigation = true,
        .auxiliary_navigation = !allowed.popups,
        .top_level_navigation_without_user_activation = !allowed.top_navigation,
        // "unless tokens contains either the allow-top-navigation-by-user-
        // activation keyword or the allow-top-navigation keyword".
        .top_level_navigation_with_user_activation = !(allowed.top_navigation_by_user_activation or allowed.top_navigation),
        .origin = !allowed.same_origin,
        .forms = !allowed.forms,
        .pointer_lock = !allowed.pointer_lock,
        .scripts = !allowed.scripts,
        // Relaxed by the same keyword as scripts.
        .automatic_features = !allowed.scripts,
        // "The sandboxed document.domain browsing context flag" - always.
        .document_domain = true,
        .propagates_to_auxiliary = !allowed.popups_to_escape_sandbox,
        .modals = !allowed.modals,
        .orientation_lock = !allowed.orientation_lock,
        .presentation = !allowed.presentation,
        .downloads = !allowed.downloads,
        // "unless tokens contains either the allow-top-navigation-to-custom-
        // protocols keyword, the allow-popups keyword, or the
        // allow-top-navigation keyword".
        .custom_protocols_navigation = !(allowed.top_navigation_to_custom_protocols or allowed.popups or allowed.top_navigation),
        .storage_access_by_user_activation = !allowed.storage_access_by_user_activation,
    };
}

/// A CSP list's "CSP-derived sandboxing flags": the sandbox directives of its
/// enforced policies, parsed.
///
/// Deviation, stated (golden rule 2): the spec text parses only the LAST
/// enforced policy's sandbox directive. Every engine unites them all, so a
/// second policy can only add restrictions: Chromium's
/// NavigationPolicyContainerBuilder::ComputeSandboxFlags ORs every
/// policy's `sandbox` into the frame's flags
/// (content/browser/renderer_host/navigation_policy_container_builder.cc),
/// Gecko's nsCSPContext::GetCSPSandboxFlags ORs every enforced policy's
/// (dom/security/nsCSPContext.cpp), and WebKit's
/// ContentSecurityPolicyDirectiveList::applySandboxPolicy adds each one to
/// the document's (enforceSandboxFlags). A report-only policy's sandbox is
/// ignored everywhere, as the spec's step 2.1 says; so is one a meta element
/// delivered, which CSP 3 excludes ("The sandbox directive ... is not
/// supported in the meta element") and which is never in a response's list.
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#csp-derived-sandboxing-flags
pub fn cspDerivedSandboxingFlags(csp_list: *const csp.CSPList) SandboxingFlagSet {
    var result: SandboxingFlagSet = .empty;
    // 2. "For each policy in cspList":
    for (csp_list.policies.items) |*policy| {
        // 2.1. "If policy's disposition is not "enforce", then continue."
        if (policy.disposition != .enforce) continue;
        if (policy.source != .header) continue;
        // 2.2. "If policy's directive set contains a directive whose name is
        // "sandbox", then append that directive to directives."
        const directive = policy.getDirective("sandbox") orelse continue;
        result = result.unionWith(directiveFlags(directive));
    }
    // 3. "If directives is empty, then return an empty sandboxing flag set."
    return result;
}

/// Step 5 for one directive: "the result of parsing the sandboxing directive
/// directive" - its value's tokens.
fn directiveFlags(directive: *const csp.Directive) SandboxingFlagSet {
    var allowed: Allowed = .{};
    for (directive.value.expressions.items) |expression| allowed.note(expression.raw_value);
    return fromAllowed(allowed);
}

/// HTML "determine the creation sandboxing flags" for a browsing context
/// given null or an element `embedder`: the union of the popup sandboxing
/// flag set (no embedder), or the embedder's iframe sandboxing flag set and
/// its node document's active sandboxing flag set.
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#determining-the-creation-sandboxing-flags
pub const CreationInputs = union(enum) {
    /// `embedder` is null: the browsing context's popup sandboxing flag set.
    popup: SandboxingFlagSet,
    /// `embedder` is an element.
    embedder: struct {
        /// Its iframe sandboxing flag set - empty for an element other than
        /// iframe, which has no sandbox attribute.
        iframe_flags: SandboxingFlagSet,
        /// Its node document's active sandboxing flag set.
        container_document_flags: SandboxingFlagSet,
    },
};

pub fn creationSandboxingFlags(inputs: CreationInputs) SandboxingFlagSet {
    return switch (inputs) {
        .popup => |flags| flags,
        .embedder => |e| e.iframe_flags.unionWith(e.container_document_flags),
    };
}

/// HTML "the rules for choosing a navigable" step 8.9: the flags a new
/// top-level traversable's popup sandboxing flag set takes from the
/// sandboxing flag set of the document that opened it - all of them when the
/// sandbox propagates to auxiliary browsing contexts, else none.
/// Spec: https://html.spec.whatwg.org/multipage/document-sequences.html#the-rules-for-choosing-a-navigable
pub fn popupSandboxingFlags(opener_flags: SandboxingFlagSet) SandboxingFlagSet {
    return if (opener_flags.propagates_to_auxiliary) opener_flags else .empty;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "the empty attribute sets every flag but the ones no keyword lifts" {
    const flags = parseSandboxingDirective("");
    try testing.expect(flags.navigation);
    try testing.expect(flags.auxiliary_navigation);
    try testing.expect(flags.top_level_navigation_without_user_activation);
    try testing.expect(flags.top_level_navigation_with_user_activation);
    try testing.expect(flags.origin);
    try testing.expect(flags.forms);
    try testing.expect(flags.pointer_lock);
    try testing.expect(flags.scripts);
    try testing.expect(flags.automatic_features);
    try testing.expect(flags.document_domain);
    try testing.expect(flags.propagates_to_auxiliary);
    try testing.expect(flags.modals);
    try testing.expect(flags.orientation_lock);
    try testing.expect(flags.presentation);
    try testing.expect(flags.downloads);
    try testing.expect(flags.custom_protocols_navigation);
    try testing.expect(flags.storage_access_by_user_activation);
}

test "the empty set is the default and is nothing sandboxed" {
    const flags: SandboxingFlagSet = .{};
    try testing.expect(flags.isEmpty());
    try testing.expect(SandboxingFlagSet.empty.isEmpty());
    try testing.expect(!flags.scripts);
    try testing.expect(!flags.origin);
}

test "allow-scripts lifts the scripts and the automatic features flags, and nothing else" {
    const flags = parseSandboxingDirective("allow-scripts");
    try testing.expect(!flags.scripts);
    try testing.expect(!flags.automatic_features);
    try testing.expect(flags.origin);
    try testing.expect(flags.forms);
    try testing.expect(flags.navigation);
    try testing.expect(flags.document_domain);
}

test "keywords are ASCII case-insensitive, split on ASCII whitespace, and unknown ones are ignored" {
    const flags = parseSandboxingDirective("\tALLOW-Scripts\n allow-same-origin\x0callow-bogus\r");
    try testing.expect(!flags.scripts);
    try testing.expect(!flags.origin);
    try testing.expect(flags.forms);
    // No other whitespace splits: a no-break space is part of the token.
    const nbsp = parseSandboxingDirective("allow-scripts\u{a0}allow-forms");
    try testing.expect(nbsp.scripts);
    try testing.expect(nbsp.forms);
}

test "allow-top-navigation lifts both top-level navigation flags and the custom protocols flag" {
    const flags = parseSandboxingDirective("allow-top-navigation");
    try testing.expect(!flags.top_level_navigation_without_user_activation);
    try testing.expect(!flags.top_level_navigation_with_user_activation);
    try testing.expect(!flags.custom_protocols_navigation);
    try testing.expect(flags.navigation);

    const by_activation = parseSandboxingDirective("allow-top-navigation-by-user-activation");
    try testing.expect(by_activation.top_level_navigation_without_user_activation);
    try testing.expect(!by_activation.top_level_navigation_with_user_activation);
    try testing.expect(by_activation.custom_protocols_navigation);
}

test "allow-popups lifts the auxiliary navigation and the custom protocols flags" {
    const flags = parseSandboxingDirective("allow-popups");
    try testing.expect(!flags.auxiliary_navigation);
    try testing.expect(!flags.custom_protocols_navigation);
    try testing.expect(flags.propagates_to_auxiliary);

    const escape = parseSandboxingDirective("allow-popups allow-popups-to-escape-sandbox");
    try testing.expect(!escape.propagates_to_auxiliary);
}

test "every keyword lifts its own flag" {
    const flags = parseSandboxingDirective("allow-forms allow-modals allow-orientation-lock allow-pointer-lock allow-presentation allow-downloads allow-storage-access-by-user-activation allow-top-navigation-to-custom-protocols");
    try testing.expect(!flags.forms);
    try testing.expect(!flags.modals);
    try testing.expect(!flags.orientation_lock);
    try testing.expect(!flags.pointer_lock);
    try testing.expect(!flags.presentation);
    try testing.expect(!flags.downloads);
    try testing.expect(!flags.storage_access_by_user_activation);
    try testing.expect(!flags.custom_protocols_navigation);
    // The ones no keyword lifts.
    try testing.expect(flags.navigation);
    try testing.expect(flags.document_domain);
}

test "parsing split tokens is parsing the joined string" {
    const tokens = [_][]const u8{ "allow-scripts", "allow-same-origin" };
    try testing.expect(parseSandboxingTokens(&tokens).eql(parseSandboxingDirective("allow-scripts allow-same-origin")));
}

test "a union keeps every flag either side sets" {
    const a = parseSandboxingDirective("allow-scripts allow-same-origin");
    const b = parseSandboxingDirective("allow-forms allow-scripts");
    const u = a.unionWith(b);
    try testing.expect(!u.scripts);
    try testing.expect(u.origin);
    try testing.expect(u.forms);
    try testing.expect(SandboxingFlagSet.empty.unionWith(a).eql(a));
}

test "creation flags: a child navigable takes its iframe's and its container document's flags" {
    const iframe = parseSandboxingDirective("allow-scripts");
    const container = parseSandboxingDirective("allow-same-origin allow-scripts");
    const flags = creationSandboxingFlags(.{ .embedder = .{ .iframe_flags = .empty, .container_document_flags = container } });
    // A frame without a sandbox attribute in a sandboxed document is
    // sandboxed as that document is.
    try testing.expect(flags.eql(container));
    try testing.expect(!flags.scripts);
    try testing.expect(flags.forms);
    const both = creationSandboxingFlags(.{ .embedder = .{ .iframe_flags = iframe, .container_document_flags = container } });
    try testing.expect(both.origin);
    try testing.expect(!both.scripts);
    // Unsandboxed container, no attribute: nothing.
    try testing.expect(creationSandboxingFlags(.{ .embedder = .{ .iframe_flags = .empty, .container_document_flags = .empty } }).isEmpty());
}

test "creation flags: a popup takes its popup sandboxing flag set" {
    const flags = parseSandboxingDirective("allow-popups allow-same-origin");
    try testing.expect(creationSandboxingFlags(.{ .popup = flags }).eql(flags));
    try testing.expect(creationSandboxingFlags(.{ .popup = .empty }).isEmpty());
}

test "a popup inherits its opener's flags unless allow-popups-to-escape-sandbox" {
    const propagating = parseSandboxingDirective("allow-popups allow-same-origin");
    try testing.expect(popupSandboxingFlags(propagating).eql(propagating));
    try testing.expect(popupSandboxingFlags(propagating).scripts);
    const escaping = parseSandboxingDirective("allow-popups allow-popups-to-escape-sandbox");
    try testing.expect(popupSandboxingFlags(escaping).isEmpty());
    try testing.expect(popupSandboxingFlags(.empty).isEmpty());
}

/// A CSP list holding `policies`, each parsed by the CSP parser as a
/// response header would be.
fn testList(allocator: std.mem.Allocator, policies: []const struct { []const u8, csp.PolicyDisposition, csp.types.PolicySource }) !csp.CSPList {
    var list = csp.CSPList.init(allocator);
    errdefer list.deinit();
    for (policies) |p| try list.append(try csp.parsing.parseSerializedCSP(allocator, p[0], p[2], p[1]));
    return list;
}

test "CSP-derived flags: none without an enforced sandbox directive" {
    const allocator = testing.allocator;
    var none = try testList(allocator, &.{});
    defer none.deinit();
    try testing.expect(cspDerivedSandboxingFlags(&none).isEmpty());
    var other = try testList(allocator, &.{.{ "script-src 'self'", .enforce, .header }});
    defer other.deinit();
    try testing.expect(cspDerivedSandboxingFlags(&other).isEmpty());
    // Report-only: ignored.
    var report = try testList(allocator, &.{.{ "sandbox", .report, .header }});
    defer report.deinit();
    try testing.expect(cspDerivedSandboxingFlags(&report).isEmpty());
    // A meta element's: ignored.
    var meta = try testList(allocator, &.{.{ "sandbox", .enforce, .meta }});
    defer meta.deinit();
    try testing.expect(cspDerivedSandboxingFlags(&meta).isEmpty());
}

test "CSP-derived flags: an enforced sandbox directive is parsed like the attribute" {
    const allocator = testing.allocator;
    var list = try testList(allocator, &.{.{ "script-src *; sandbox allow-scripts ALLOW-SAME-ORIGIN", .enforce, .header }});
    defer list.deinit();
    const flags = cspDerivedSandboxingFlags(&list);
    try testing.expect(flags.eql(parseSandboxingDirective("allow-scripts allow-same-origin")));
    try testing.expect(!flags.scripts);
    try testing.expect(!flags.origin);
    try testing.expect(flags.forms);
    var empty = try testList(allocator, &.{.{ "sandbox", .enforce, .header }});
    defer empty.deinit();
    try testing.expect(cspDerivedSandboxingFlags(&empty).eql(parseSandboxingDirective("")));
}

test "CSP-derived flags: every enforced policy's sandbox counts, as in every engine" {
    const allocator = testing.allocator;
    var list = try testList(allocator, &.{
        .{ "sandbox allow-scripts allow-same-origin", .enforce, .header },
        .{ "sandbox allow-same-origin", .enforce, .header },
    });
    defer list.deinit();
    const flags = cspDerivedSandboxingFlags(&list);
    // The second policy takes scripts away; the first cannot give them back.
    try testing.expect(flags.scripts);
    try testing.expect(!flags.origin);
}
