//! Lane sel1 (batch 1): CSS Transitions 2 3.3, the @starting-style rule.
//! An element (or pseudo-element) with no before-change style at a style
//! change event - never resolved, or not rendered at the previous one -
//! transitions from its starting style: the after-change style with the
//! rules inside @starting-style applied in addition. Those rules never
//! apply to the after-change style, a starting style that is display: none
//! starts nothing, and CSSOM reads the rule as a CSSStartingStyleRule.
//! The WPT side: css/css-transitions/starting-style-*.html.
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

const sheet =
    \\const style = document.createElement('style');
    \\style.textContent = `
    \\  .t { transition: background-color 100s steps(2, start); background-color: white; }
    \\  @starting-style { .t.from-black { background-color: black; } }
    \\  @starting-style { .t.from-none { display: none; background-color: black; } }
    \\  .t.hidden { display: none; }
    \\`;
    \\document.head.append(style);
;

fn firstStyleTransitionsFromStartingStyle() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(sheet);
    // Never resolved: the starting style (black) is its before-change style.
    try expectScript(page,
        \\globalThis.a = document.body.appendChild(document.createElement('div'));
        \\a.className = 't from-black';
        \\getComputedStyle(a).backgroundColor
    , "rgb(128, 128, 128)");
    // No @starting-style rule matches: no starting style, no transition.
    try expectScript(page,
        \\globalThis.b = document.body.appendChild(document.createElement('div'));
        \\b.className = 't';
        \\getComputedStyle(b).backgroundColor
    , "rgb(255, 255, 255)");
    // A display: none starting style starts nothing.
    try expectScript(page,
        \\globalThis.c = document.body.appendChild(document.createElement('div'));
        \\c.className = 't from-none';
        \\getComputedStyle(c).backgroundColor
    , "rgb(255, 255, 255)");
    try expectScript(page, "String(document.getAnimations().length)", "1");
}

test "an element's first style transitions from its starting style" {
    try helpers.onFreshThread(firstStyleTransitionsFromStartingStyle);
}

fn startingStyleNeverAppliesToAfterChange() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(sheet);
    // Rendered before: its before-change style exists, and the starting
    // rules stay out of the after-change style.
    try expectScript(page,
        \\globalThis.a = document.body.appendChild(document.createElement('div'));
        \\a.className = 't';
        \\getComputedStyle(a).backgroundColor;
        \\a.className = 't from-black';
        \\getComputedStyle(a).backgroundColor + '|' + document.getAnimations().length
    , "rgb(255, 255, 255)|0");
    // Not rendered at its previous style change event (display: none), then
    // shown: no before-change style, so the starting style.
    try expectScript(page,
        \\a.className = 't from-black hidden';
        \\getComputedStyle(a).backgroundColor;
        \\a.className = 't from-black';
        \\getComputedStyle(a).backgroundColor
    , "rgb(128, 128, 128)");
}

test "starting style rules never apply to an after-change style; a shown element transitions from its starting style" {
    try helpers.onFreshThread(startingStyleNeverAppliesToAfterChange);
}

fn startingStyleRuleInCssom() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(sheet);
    try expectScript(page,
        \\const rules = document.styleSheets[0].cssRules;
        \\const r = rules[1];
        \\[rules.length, r.constructor.name, r instanceof CSSGroupingRule, r.cssRules.length, r.cssText].join('|')
    , "4|CSSStartingStyleRule|true|1|@starting-style {\n  .t.from-black { background-color: black; }\n}");
    try expectScript(page,
        \\const g = document.styleSheets[0].cssRules[1];
        \\g.insertRule('.x { color: red }', 1);
        \\[g.cssRules.length, g.cssRules[1].parentRule === g].join('|')
    , "2|true");
}

test "an @starting-style rule is a CSSStartingStyleRule, a CSSGroupingRule" {
    try helpers.onFreshThread(startingStyleRuleInCssom);
}
