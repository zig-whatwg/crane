//! Lane maj1: the shadow host seen from inside its shadow tree is featureless
//! (Selectors 4 3.2.1, CSS Shadow 1 3.1.1) - what may still match it:
//! - :not() of a selector allowed to match it (`:not(:host(.nope))`), never
//!   of one that is not (`:not(.foo:host)`, `:not(:hover)`);
//! - :has() beside another allowed simple selector (`:host:has(.inner)`),
//!   whose relative selectors are found in the host's shadow tree - "the
//!   contents of the shadow tree treated as its children" - never among its
//!   light-tree children or siblings;
//! - a pseudo-element only after an allowed compound (`:host::before`, not
//!   `::before`);
//! - under a default namespace, a compound of only :host (the browsers:
//!   `:is(:host)` and `:where(:host)` stop matching).
//! Expectations: css/selectors/featureless-006.html, featureless-007.html and
//! invalidation/host-has-shadow-tree-element-at-{subject,nonsubject}-
//! position.html at wpt.fyi aligned run 2358bd4835 (majorities in comments).
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const css = dom.style.css;
const rules = dom.style.rules;

const a = std.testing.allocator;

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

const Fixture = struct {
    context: runtime.ContextData,
    document: *runtime.Instance,
    root: *runtime.Instance,
    host: *runtime.Instance,
    shadow: *runtime.Instance,

    fn element(self: *Fixture, class: []const u8) !*runtime.Instance {
        const e = try interfaces.Document.call_createElement(self.document, str("div"), .{ .was_passed = false, .value = undefined });
        if (class.len != 0) try interfaces.Element.call_setAttribute(e, str("class"), .{ .domstring = str(class) });
        return e;
    }

    fn matches(self: *Fixture, text: []const u8, map: ?*const css.namespace_map.NamespaceMap, pseudo: ?[]const u8) !bool {
        var ast = try rules.parseSelector(a, text, map);
        defer ast.deinit();
        var reads: dom.selector_matching.StateReads = .{};
        var matcher = dom.selector_matching.StyleMatcher.initForHost(self.host, self.shadow, &reads) orelse return error.MissingMatcher;
        return matcher.matchesHost(self.host, &ast.selectors[0], pseudo);
    }

    fn expect(self: *Fixture, text: []const u8, map: ?*const css.namespace_map.NamespaceMap, pseudo: ?[]const u8, expected: bool) !void {
        const got = try self.matches(text, map, pseudo);
        if (got != expected) std.debug.print("\"{s}\"{s}: expected {}\n", .{ text, if (pseudo != null) " (::before)" else "", expected });
        try std.testing.expectEqual(expected, got);
    }
};

fn run(body: *const fn (*Fixture) anyerror!void) !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var fixture: Fixture = undefined;
    fixture.context = try runtime.ContextData.init(a, .{});
    defer fixture.context.deinit();
    fixture.document = try interfaces.Document.init(a, &fixture.context);
    var shadow: ?*runtime.Instance = null;
    defer if (shadow) |root| interfaces.ShadowRoot.deinit(root);
    // The host severs its shadow link before the separately owned root dies.
    defer interfaces.Document.deinit(fixture.document);
    try dom.document_internals.setContentType(fixture.document, "text/html");
    try dom.document_internals.setDocumentType(fixture.document, .html);
    fixture.root = try fixture.element("");
    _ = try interfaces.Node.call_appendChild(fixture.document, fixture.root);
    fixture.host = try fixture.element("host");
    _ = try interfaces.Node.call_appendChild(fixture.root, fixture.host);
    shadow = try interfaces.Element.call_attachShadow(fixture.host, .{ .mode = ._open_ });
    try dom.node_document.set(shadow.?, fixture.document);
    fixture.shadow = shadow.?;
    try body(&fixture);
}

fn onThread(body: *const fn (*Fixture) anyerror!void) !void {
    const Run = struct {
        fn call(f: *const fn (*Fixture) anyerror!void, result: *anyerror!void) void {
            result.* = run(f);
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.call, .{ body, &result });
    thread.join();
    return result;
}

fn logicalCombinations(f: *Fixture) !void {
    _ = try interfaces.Node.call_appendChild(f.shadow, try f.element("inner"));
    // featureless-006: all three browsers.
    for ([_]struct { []const u8, bool }{
        .{ "*", false },                  .{ "div", false },                     .{ ".host", false },
        .{ ":host", true },               .{ ":host(.host)", true },             .{ ":host(.nope)", false },
        .{ ":not(:host)", false },        .{ ":not(:not(:not(:host)))", false }, .{ ":not(:is(:host, div))", false },
        .{ ":where(:host)", true },       .{ ":not(div)", false },               .{ ":not(.foo)", false },
        .{ ":not(:hover)", false },       .{ ":not(:host.host)", false },        .{ ":not(.foo:host)", false },
        .{ ":not(:host > .foo)", false }, .{ ":not(:host(.host))", false },      .{ ":has(.inner)", false },
        .{ ":not(:has(.inner))", false }, .{ ":not(:host:has(.inner))", false }, .{ ":not(:has(.inner):host)", false },
        .{ "[a]:host", false },           .{ ":nth-child(1):host", false },
    }) |case| try f.expect(case[0], null, null, case[1]);
    // Chrome and Firefox (Safari matches no :not() on the host).
    for ([_][]const u8{ ":not(:not(:host))", ":is(:not(:not(:host)))", ":not(:host(.nope))", ":is(:not(:host(.nope)))" }) |text|
        try f.expect(text, null, null, true);
    // Chrome and Safari (Firefox matches no :has() on the host); with :not(),
    // Chrome - the two mechanisms' majorities together.
    try f.expect(":host:has(.inner)", null, null, true);
    try f.expect(":not(:host:has(.nope))", null, null, true);
    // Selectors 4 3.2.1: where :has() sits in the compound makes no
    // difference. All three browsers fail this one: Firefox has no :has() on
    // the host, Safari no :not() on it, and Chrome, the only one with both
    // mechanisms, seems to need :has() after :host (it passes
    // `:not(:host:has(.nope))`). Golden rule 2's mechanism-by-mechanism step
    // finds no majority for the compound's order, so the spec decides.
    try f.expect(":not(:has(.nope):host)", null, null, true);
}

test "a logical combination matches the featureless host only if its argument may" {
    try onThread(&logicalCombinations);
}

fn pseudoElements(f: *Fixture) !void {
    // featureless-006: all three browsers; `:not(:not(:host))::before`
    // Chrome and Firefox.
    try f.expect("::before", null, "before", false);
    try f.expect(":host::before", null, "before", true);
    try f.expect(":is(:host)::before", null, "before", true);
    try f.expect(":not(:not(:host))::before", null, "before", true);
    try f.expect(":not(:hover)::before", null, "before", false);
}

test "a pseudo-element of the featureless host follows an allowed compound" {
    try onThread(&pseudoElements);
}

fn hostHas(f: *Fixture) !void {
    // The light tree: a .child > .descendant under the host, a .sibling
    // after it - none of them counts.
    const light_child = try f.element("child");
    _ = try interfaces.Node.call_appendChild(f.host, light_child);
    _ = try interfaces.Node.call_appendChild(light_child, try f.element("descendant"));
    _ = try interfaces.Node.call_appendChild(f.root, try f.element("sibling"));
    // The shadow tree: #shadow_child > #shadow_descendant.
    const shadow_child = try f.element("");
    _ = try interfaces.Node.call_appendChild(f.shadow, shadow_child);
    const shadow_descendant = try f.element("");
    _ = try interfaces.Node.call_appendChild(shadow_child, shadow_descendant);
    try f.expect(":host:has(.descendant)", null, null, false);
    try f.expect(":host:has(> .child)", null, null, false);
    try f.expect(":host:has(~ .sibling)", null, null, false);
    try interfaces.Element.call_setAttribute(shadow_descendant, str("class"), .{ .domstring = str("descendant") });
    try f.expect(":host:has(.descendant)", null, null, true);
    try f.expect(":host:has(> .descendant)", null, null, false);
    try f.expect(":host:has(:is(.ancestor .descendant))", null, null, false);
    try interfaces.Element.call_setAttribute(shadow_child, str("class"), .{ .domstring = str("child ancestor") });
    try f.expect(":host:has(> .child)", null, null, true);
    try f.expect(":host:has(> .child > .descendant)", null, null, true);
    try f.expect(":host:has(:is(.ancestor .descendant))", null, null, true);
    try f.expect(":host:has(.descendant):has(> .child)", null, null, true);
    try f.expect(":host(.host):has(> .child > .descendant)", null, null, true);
    try f.expect(":host(.nope):has(> .child)", null, null, false);
    // The light-tree host's ancestors are not above the featureless host.
    try f.expect(":host:has(.host .descendant)", null, null, false);
}

test ":host:has() finds its relative selectors in the host's shadow tree" {
    try onThread(&hostHas);
}

fn defaultNamespace(f: *Fixture) !void {
    // featureless-007: all three browsers.
    for ([_][]const u8{ "http://example.org/ns", "http://www.w3.org/1999/xhtml" }) |uri| {
        const map = try css.namespace_map.NamespaceMap.create(a, &.{}, uri);
        defer map.release();
        try f.expect(":host", map, null, true);
        try f.expect(":host:host", map, null, true);
        try f.expect(":is(:host)", map, null, false);
        try f.expect(":where(:host)", map, null, false);
        try f.expect(":not(:not(:host))", map, null, false);
    }
    try f.expect(":is(:host)", null, null, true);
    try f.expect(":where(:host)", null, null, true);
}

test "under a default namespace only a compound of :host matches the featureless host" {
    try onThread(&defaultNamespace);
}
