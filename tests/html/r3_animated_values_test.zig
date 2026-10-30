//! Lane rendering3: animated values in computed style on a real Browser -
//! the effect stack (Web Animations 1 5.4), composite add/accumulate, the
//! animation origin (Cascade 5 6.2-6.3), keyframes computed through the
//! cascade (5.3.2: em, var(), inherit), inheritance into descendants, and
//! the per-target style key (only animated elements resolve again).
//!
//! Each test runs on a thread of its own (a Browser per thread).
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

fn expectScript(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const value = try page.evaluate(source);
    defer std.testing.allocator.free(value);
    std.testing.expectEqualStrings(expected, value) catch |err| {
        std.debug.print("script: {s}\n", .{source});
        return err;
    };
}

const setup =
    \\globalThis.target = document.createElement('div');
    \\target.id = 'target';
    \\globalThis.child = document.createElement('span');
    \\target.appendChild(child);
    \\document.body.appendChild(target);
    \\globalThis.cs = (e, p) => getComputedStyle(e).getPropertyValue(p);
;

fn interpolatedValues() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup);
    try page.run(
        \\globalThis.a = target.animate([{ opacity: 0, marginLeft: '0px', color: 'rgb(0, 0, 0)' },
        \\  { opacity: 1, marginLeft: '100px', color: 'rgb(200, 100, 0)' }], 1000);
        \\a.pause(); a.currentTime = 250;
    );
    try expectScript(page, "cs(target, 'opacity')", "0.25");
    try expectScript(page, "cs(target, 'margin-left')", "25px");
    try expectScript(page, "cs(target, 'color')", "rgb(50, 25, 0)");
    // Inherited: the child follows its animated parent.
    try expectScript(page, "cs(child, 'color')", "rgb(50, 25, 0)");
    // Seeking moves the value at once (no frame needed).
    try page.run("a.currentTime = 500;");
    try expectScript(page, "cs(target, 'margin-left')", "50px");
    try expectScript(page, "cs(child, 'color')", "rgb(100, 50, 0)");
    // Cancel restores the base value.
    try page.run("a.cancel();");
    try expectScript(page, "cs(target, 'margin-left')", "0px");
    try expectScript(page, "cs(target, 'opacity')", "1");
}

test "r3: animated values in computed style, inherited, live on seek, gone on cancel" {
    try helpers.onFreshThread(interpolatedValues);
}

fn importantAndOrigins() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup);
    try page.run(
        \\target.style.setProperty('margin-left', '7px', 'important');
        \\target.style.marginRight = '7px';
        \\globalThis.a = target.animate({ marginLeft: ['0px', '100px'], marginRight: ['0px', '100px'] }, 1000);
        \\a.pause(); a.currentTime = 500;
    );
    // Cascade 5 6.3: important declarations beat the animation origin;
    // normal ones lose to it.
    try expectScript(page, "cs(target, 'margin-left')", "7px");
    try expectScript(page, "cs(target, 'margin-right')", "50px");
}

test "r3: !important beats the animation origin, normal declarations do not" {
    try helpers.onFreshThread(importantAndOrigins);
}

fn compositeAndContext() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup);
    try page.run(
        \\target.style.marginLeft = '10px';
        \\target.style.fontSize = '10px';
        \\target.style.setProperty('--w', '40px');
        \\globalThis.a = target.animate({ marginLeft: ['0px', '100px'] }, { duration: 1000, composite: 'add' });
        \\globalThis.b = target.animate({ marginLeft: ['0px', '20px'] }, { duration: 1000, composite: 'accumulate' });
        \\globalThis.c = target.animate({ width: ['2em', 'var(--w)'] }, 1000);
        \\for (const x of [a, b, c]) { x.pause(); x.currentTime = 500; }
    );
    // 10 (underlying) + 50 (add) + 10 (accumulate).
    try expectScript(page, "cs(target, 'margin-left')", "70px");
    // 2em = 20px against the element's font-size; var(--w) = 40px.
    try expectScript(page, "cs(target, 'width')", "30px");
    // An implicit from-keyframe takes the underlying value.
    try page.run("const d = target.animate({ fontSize: '30px' }, 1000); d.pause(); d.currentTime = 500;");
    try expectScript(page, "cs(target, 'font-size')", "20px");
    // ... and em keyframes of other properties resolve against it.
    try expectScript(page, "cs(target, 'width')", "40px");
}

test "r3: add and accumulate stack; keyframes compute with em, var() and the animated font-size" {
    try helpers.onFreshThread(compositeAndContext);
}

fn onlyTargetsResolveAgain() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup);
    try page.run(
        \\globalThis.other = document.createElement('p');
        \\document.body.appendChild(other);
        \\globalThis.a = target.animate({ opacity: [0, 1] }, 1000);
        \\a.pause(); a.currentTime = 100;
        \\cs(other, 'opacity'); cs(target, 'opacity');
    );
    try expectScript(page, "cs(target, 'opacity')", "0.1");
    try page.run("a.currentTime = 900;");
    try expectScript(page, "cs(target, 'opacity')", "0.9");
    try expectScript(page, "cs(other, 'opacity')", "1");
}

test "r3: a running animation moves only its target's style" {
    try helpers.onFreshThread(onlyTargetsResolveAgain);
}

fn commitStylesWritesEffectValues() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup);
    try page.run(
        \\target.style.marginLeft = '10px';
        \\globalThis.a = target.animate({ marginLeft: ['0px', '100px'], opacity: [0, 1] }, 1000);
        \\globalThis.b = target.animate({ marginLeft: ['0px', '20px'] }, { duration: 1000, composite: 'add' });
        \\for (const x of [a, b]) { x.pause(); x.currentTime = 500; }
        \\a.commitStyles();
        \\a.cancel(); b.cancel();
    );
    // The partial stack stops at `a`: b's add is not committed.
    try expectScript(page, "target.style.marginLeft", "50px");
    try expectScript(page, "target.style.opacity", "0.5");
    // Endpoint-inclusive: a finished animation without fill commits its end.
    try page.run(
        \\globalThis.c = target.animate({ marginLeft: ['0px', '30px'] }, 1000);
        \\c.finish(); c.commitStyles();
    );
    try expectScript(page, "target.style.marginLeft", "30px");
    // A pseudo-element target cannot take a style attribute; a target that
    // is not rendered is an InvalidStateError.
    try expectScript(page,
        \\(() => { const d = target.animate({ opacity: [0, 1] }, { duration: 1000, pseudoElement: '::before' });
        \\  try { d.commitStyles(); return 'no'; } catch (e) { return e.name; } })()
    , "NoModificationAllowedError");
    try expectScript(page,
        \\(() => { target.style.display = 'none'; const d = target.animate({ opacity: [0, 1] }, 1000);
        \\  try { d.commitStyles(); return 'no'; } catch (e) { return e.name; } })()
    , "InvalidStateError");
}

test "r3: commitStyles writes the partial stack's values into the style attribute" {
    try helpers.onFreshThread(commitStylesWritesEffectValues);
}
