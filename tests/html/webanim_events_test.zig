//! Lane rendering2: Web Animations' "update animations and send events"
//! (HTML update the rendering step 11) on a real Browser loop - the CSS
//! animation and transition events the timing model queues for a
//! CSSAnimation or CSSTransition, made here as the style engine will make
//! them (nothing makes them from CSS yet), and the lifetime of an animation
//! nothing but its own work keeps.
//!
//! Each test runs on a thread of its own (a Browser per thread).
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const helpers = @import("edges_node_holders_helpers.zig");

const animations = dom.animations;

fn documentOf(page: helpers.Page) *runtime.Instance {
    return page.browser.current_context.?.document_instance.?;
}

/// Pump the page's loop until `condition` evaluates to "true".
fn pumpUntil(page: helpers.Page, condition: []const u8, turns: usize) !void {
    var turn: usize = 0;
    while (turn < turns) : (turn += 1) {
        _ = try page.browser.runEventLoopBlocking(5);
        const value = try page.evaluate(condition);
        defer std.testing.allocator.free(value);
        if (std.mem.eql(u8, value, "true")) return;
    }
    const value = try page.evaluate("log.join(' | ')");
    defer std.testing.allocator.free(value);
    std.debug.print("condition never held: {s}; log: {s}\n", .{ condition, value });
    return error.ConditionNeverHeld;
}

const Kind = animations.css_events.Kind;

/// Make a CSSAnimation or CSSTransition owned by `owner`, named `name`,
/// with an effect of `iterations` x `duration` ms on the document's default
/// timeline, and play it.
fn makeCssAnimation(document: *runtime.Instance, owner: *runtime.Instance, kind: Kind, name: []const u8, duration: f64, iterations: f64) !*runtime.Instance {
    const realm = document.ctx;
    const effect = try interfaces.KeyframeEffect.init(realm.allocator, realm);
    const effect_model = animations.hooks.effectOf(effect) orelse return error.NoEffectModel;
    effect_model.keyframe_effect = true;
    effect_model.setTarget(owner);
    try animations.options.updateTiming(effect_model, .{ .duration = .{ .number = duration }, .iterations = iterations });
    const animation = switch (kind) {
        .animation => try interfaces.CSSAnimation.init(realm.allocator, realm),
        .transition => try interfaces.CSSTransition.init(realm.allocator, realm),
    };
    try animations.constructAnimation(animation, effect, .{ .value = try animations.defaultTimeline(document) });
    const model = animations.hooks.animationOf(animation) orelse return error.NoAnimationModel;
    try animations.css_events.attach(model, kind, owner, "", name);
    try model.play(true);
    return animation;
}

const listen =
    \\globalThis.log = [];
    \\const owner = document.createElement('div');
    \\owner.id = 'owner';
    \\document.body.appendChild(owner);
    \\for (const type of ['animationstart', 'animationiteration', 'animationend', 'animationcancel',
    \\                    'transitionrun', 'transitionstart', 'transitionend', 'transitioncancel'])
    \\  owner.addEventListener(type, e => log.push([type, e.animationName ?? e.propertyName, e.elapsedTime,
    \\    e.isTrusted, e.animation ? e.animation.constructor.name : 'none'].join(':')));
;

fn ownerOf(document: *runtime.Instance) !*runtime.Instance {
    return (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("owner"))) orelse error.NoOwner;
}

fn animationEventsFollowThePhases() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(listen);
    const document = documentOf(page);
    _ = try makeCssAnimation(document, try ownerOf(document), .animation, "spin", 150, 2);
    try pumpUntil(page, "log.length >= 3", 800);
    const result = try page.evaluate("log.join(' | ')");
    defer std.testing.allocator.free(result);
    // CSS Animations 2 5.1: start (interval start), one iteration (the
    // iteration boundary x the duration), end (interval end); trusted, at the
    // owning element, carrying the CSSAnimation.
    try std.testing.expectEqualStrings(
        "animationstart:spin:0:true:CSSAnimation | animationiteration:spin:0.15:true:CSSAnimation | animationend:spin:0.3:true:CSSAnimation",
        result,
    );
}

test "a CSS animation's events follow its phases: start, iteration, end" {
    try helpers.onFreshThread(animationEventsFollowThePhases);
}

fn transitionEventsAndCancel() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(listen);
    const document = documentOf(page);
    const owner = try ownerOf(document);
    _ = try makeCssAnimation(document, owner, .transition, "width", 50, 1);
    try pumpUntil(page, "log.length >= 3", 800);
    {
        const result = try page.evaluate("log.join(' | ')");
        defer std.testing.allocator.free(result);
        try std.testing.expectEqualStrings(
            "transitionrun:width:0:true:CSSTransition | transitionstart:width:0:true:CSSTransition | transitionend:width:0.05:true:CSSTransition",
            result,
        );
    }
    // A running CSS animation canceled: animationcancel with its active
    // time when canceled.
    try page.run("log.length = 0");
    const running = try makeCssAnimation(document, owner, .animation, "long", 100000, 1);
    try pumpUntil(page, "log.length >= 1", 800);
    const model = animations.hooks.animationOf(running) orelse return error.NoAnimationModel;
    model.cancel();
    try pumpUntil(page, "log.length >= 2", 800);
    const result = try page.evaluate("log.map(e => e.split(':')[0]).join(' | ')");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("animationstart | animationcancel", result);
}

test "a CSS transition's run, start and end; a CSS animation's cancel" {
    try helpers.onFreshThread(transitionEventsAndCancel);
}

fn noOwnerNoCssEvents() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(listen);
    const document = documentOf(page);
    const animation = try makeCssAnimation(document, try ownerOf(document), .animation, "gone", 30, 1);
    const model = animations.hooks.animationOf(animation) orelse return error.NoAnimationModel;
    // The style engine disassociates it (CSS Animations 2 2.1): no CSS
    // events, but the playback events still come.
    animations.css_events.detach(model);
    try page.run("globalThis.playbackFinished = false; document.getAnimations()[0].onfinish = () => { playbackFinished = true; };");
    try pumpUntil(page, "playbackFinished", 800);
    const result = try page.evaluate("String(log.length)");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("0", result);
}

test "without an owning element there are no CSS events, only playback events" {
    try helpers.onFreshThread(noOwnerNoCssEvents);
}

fn unreferencedAnimationsGoOnceIdle() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // A thousand animations script drops at once: canceled, each is idle and
    // keeps nothing alive; a collection takes them, and the registry's
    // links to them retire (no growth across the rounds).
    try page.run(
        \\globalThis.target = document.body.appendChild(document.createElement('div'));
        \\globalThis.churn = () => { for (let i = 0; i < 1000; i++) target.animate(null, 1000).cancel(); };
        \\churn();
    );
    try page.run("collectNow(); churn(); collectNow(); churn(); collectNow();");
    const result = try page.evaluate("String(document.getAnimations().length)");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("0", result);
    // The registry keeps links only; dead ones retire as it grows.
    const registry = animations.registry.of(documentOf(page).ctx) orelse return error.NoRegistry;
    try std.testing.expect(registry.animations.items.len <= 3000);
}

test "canceled, unreferenced animations are collected" {
    try helpers.onFreshThread(unreferencedAnimationsGoOnceIdle);
}
