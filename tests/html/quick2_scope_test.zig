//! Lane quick2: CSS Cascade 6 3.5, the @scope rule, in the cascade. A
//! scoped style rule matches only elements in a scope its @scope rule makes
//! - an inclusive descendant of a scoping root that matches <scope-start>,
//! not inside a scoping limit that matches <scope-end> - with :scope the
//! root and & :where(:scope); its selector is relative to :scope, the
//! implied anchor adding no specificity; scope proximity orders the cascade
//! after specificity; an @scope with no <scope-start> is scoped to its
//! owner node's parent (a shadow tree's host, or the document); @scope rules
//! nest. The WPT side: css/css-cascade/scope-*.html.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

fn expectScript(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const actual = try page.evaluate(source);
    defer std.testing.allocator.free(actual);
    std.testing.expectEqualStrings(expected, actual) catch |err| {
        std.debug.print("{s}\n", .{source});
        return err;
    };
}

/// A page whose body is `markup` after a <style> holding `css`, and a
/// `z(selector)` helper reading an element's computed z-index.
fn openWith(css: []const u8, markup: []const u8) !helpers.Page {
    const page = try helpers.Page.open();
    errdefer page.close();
    var buffer: [4096]u8 = undefined;
    const source = try std.fmt.bufPrint(&buffer,
        \\document.body.innerHTML = `<style>{s}</style>{s}`;
        \\globalThis.z = (s) => getComputedStyle(document.querySelector(s)).zIndex;
    , .{ css, markup });
    try page.run(source);
    return page;
}

fn scopesItsRootsDescendants() !void {
    const page = try openWith(
        "@scope (.a) { span { z-index: 1; } .a { z-index: 2; } }",
        "<div class=a id=a><span id=in></span></div><div class=b><span id=out></span></div><span id=top></span>",
    );
    defer page.close();
    try expectScript(page, "[z('#in'), z('#out'), z('#top'), z('#a')].join()", "1,auto,auto,auto");
}

test "a scoped rule matches inside its scoping root only, and not the root without :scope" {
    try helpers.onFreshThread(scopesItsRootsDescendants);
}

fn scopeAndNestingSelectorMatchTheRoot() !void {
    const page = try openWith(
        "@scope (.a) { :scope { z-index: 1; } } @scope (.b) { & { z-index: 2; } } @scope (.c) { z-index: 3; }",
        "<div class=a id=a><div class=a id=inner></div></div><div class=b id=b></div><div class=c id=c><p id=p></p></div>",
    );
    defer page.close();
    try expectScript(page, "[z('#a'), z('#inner'), z('#b'), z('#c'), z('#p')].join()", "1,1,2,3,auto");
}

test ":scope, & and scoped declarations match the scoping root" {
    try helpers.onFreshThread(scopeAndNestingSelectorMatchTheRoot);
}

fn limitsExcludeTheirSubtrees() !void {
    const page = try openWith(
        "@scope (.a) to (.c) { span { z-index: 1; } } @scope (.x) to (:scope > .y) { i { z-index: 2; } }",
        "<div class=a><div class=b><span id=in></span></div><div class=c><span id=limited></span></div><span class=c id=self></span></div>" ++
            "<div class=x><div class=y><i id=child-limit></i></div><div><div class=y><i id=deep></i></div></div></div>",
    );
    defer page.close();
    try expectScript(page, "[z('#in'), z('#limited'), z('#self'), z('#child-limit'), z('#deep')].join()", "1,auto,auto,auto,2");
}

test "a scoping limit and its subtree are out of scope; :scope in <scope-end> is the root" {
    try helpers.onFreshThread(limitsExcludeTheirSubtrees);
}

fn relativeSelectorsAndSpecificity() !void {
    // The implied :scope adds nothing: `.b` in @scope is (0,1,0) and loses
    // to a later (0,1,0) `.b`... but scope proximity decides first among
    // equal specificities, so the scoped one wins over an unscoped later one.
    const page = try openWith(
        "@scope (#main) { .b { z-index: 1; } > .c { z-index: 2; } } .b { z-index: 9; } .c { z-index: 9; } .x.y { z-index: 3; } @scope (#main) { .x { z-index: 4; } }",
        "<div id=main><div class=b id=b></div><div class=c id=c></div><div><div class=c id=deep-c></div></div><div class='x y' id=xy></div></div>",
    );
    defer page.close();
    try expectScript(page, "[z('#b'), z('#c'), z('#deep-c'), z('#xy')].join()", "1,2,9,3");
}

test "scoped selectors are relative to :scope; the implied anchor adds no specificity; proximity after specificity" {
    try helpers.onFreshThread(relativeSelectorsAndSpecificity);
}

fn proximityPicksTheNearerRoot() !void {
    const page = try openWith(
        "@scope (.light) { p { z-index: 1; } } @scope (.dark) { p { z-index: 2; } }",
        "<div class=light><p id=light-p></p><div class=dark><p id=dark-p></p><div class=light><p id=inner-light-p></p></div></div></div>",
    );
    defer page.close();
    try expectScript(page, "[z('#light-p'), z('#dark-p'), z('#inner-light-p')].join()", "1,2,1");
}

test "scope proximity: the declaration with the nearer scoping root wins" {
    try helpers.onFreshThread(proximityPicksTheNearerRoot);
}

fn implicitScopeIsTheStyleElementsParent() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = `<div id=host><style>@scope { p { z-index: 1; } :scope { z-index: 2; } }</style><p id=in></p></div><p id=out></p>`;
        \\globalThis.z = (s) => getComputedStyle(document.querySelector(s)).zIndex;
    );
    try expectScript(page, "[z('#in'), z('#out'), z('#host')].join()", "1,auto,2");
}

test "an @scope with no <scope-start> is scoped to its owner node's parent element" {
    try helpers.onFreshThread(implicitScopeIsTheStyleElementsParent);
}

fn implicitScopeOfAConstructedSheetIsTheDocument() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = `<div class=a id=inner></div>`;
        \\globalThis.z = (e) => getComputedStyle(e).zIndex;
        \\globalThis.adopt = (text) => { const s = new CSSStyleSheet(); s.replaceSync(text); document.adoptedStyleSheets = [s]; };
    );
    try expectScript(page, "adopt('@scope { .a { z-index: 1; } }'); z(inner)", "1");
    try expectScript(page, "adopt('@scope { html { z-index: 1; } }'); z(document.documentElement)", "1");
    try expectScript(page, "adopt('@scope { :scope { z-index: 1; } }'); [z(document.documentElement), z(document.body)].join()", "auto,auto");
    try expectScript(page, "adopt('@scope { > html { z-index: 1; } > body { z-index: 1; } }'); [z(document.documentElement), z(document.body)].join()", "1,auto");
}

test "a constructed sheet's implicit scope is its document: html is in it, :scope matches no element" {
    try helpers.onFreshThread(implicitScopeOfAConstructedSheetIsTheDocument);
}

fn nestedScopesAreRelativeToTheOuterRoot() !void {
    const page = try openWith(
        "@scope (.parent) { @scope (:scope > .child) to (:scope .limit) { :scope .content { z-index: 1; } } }",
        "<div class=parent><div class=child><div class=content id=yes></div><div class=limit><div class=content id=limited></div></div></div><div><div class=child><div class=content id=grandchild></div></div></div></div>" ++
            "<div class=child><div class=content id=no-parent></div></div>",
    );
    defer page.close();
    try expectScript(page, "[z('#yes'), z('#limited'), z('#grandchild'), z('#no-parent')].join()", "1,auto,auto,auto");
}

test "a nested @scope's <scope-start> is relative to the outer scoping root" {
    try helpers.onFreshThread(nestedScopesAreRelativeToTheOuterRoot);
}

fn scopeInsideAStyleRule() !void {
    const page = try openWith(
        ".a { @scope (.b) { .c { z-index: 1; } } }",
        "<div class=a><div class=b><div class=c id=yes></div></div></div><div class=b><div class=c id=no></div></div>",
    );
    defer page.close();
    try expectScript(page, "[z('#yes'), z('#no')].join()", "1,auto");
}

test "an @scope inside a style rule: its <scope-start> is relative to the parent selector (&)" {
    try helpers.onFreshThread(scopeInsideAStyleRule);
}

fn shadowHostIsTheImplicitRoot() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try expectScript(page,
        \\const host = document.body.appendChild(document.createElement('div'));
        \\const root = host.attachShadow({ mode: 'open' });
        \\root.innerHTML = `<style>@scope { :scope { z-index: 1; } div { z-index: 2; } } @scope (:host) { span { z-index: 3; } }</style><div id=d><span id=s></span></div>`;
        \\[getComputedStyle(host).zIndex, getComputedStyle(root.getElementById('d')).zIndex, getComputedStyle(root.getElementById('s')).zIndex].join()
    , "1,2,3");
}

test "in a shadow tree the featureless host is the implicit scoping root, and :host can be a <scope-start>" {
    try helpers.onFreshThread(shadowHostIsTheImplicitRoot);
}
