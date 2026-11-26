//! Lane rend1: HTML "update the rendering" steps 9 (scroll events),
//! 13 (canvas context lost), 20 (rendering time), 21 (paint timing), and
//! 23 (CSS Position 4 top layer removals).
const std = @import("std");
const dom = @import("dom");
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const testing = std.testing;
const helper = @import("edges_node_holders_helpers.zig");

test "step 9: viewport scroll fires bubbling scroll then scrollend before rAF and deduplicates" {
    try helper.onFreshThread(viewportScrollEvents);
}

fn viewportScrollEvents() !void {
    const page = try helper.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.events = [];
        \\document.addEventListener('scroll', (e) => events.push('doc:scroll:' + e.bubbles));
        \\window.addEventListener('scroll', (e) => events.push('win:scroll:' + (e.target === document)));
        \\document.addEventListener('scrollend', (e) => events.push('doc:scrollend:' + e.bubbles));
        \\window.addEventListener('scrollend', (e) => events.push('win:scrollend:' + (e.target === document)));
        \\// Multiple scrolls before one frame deduplicate to one scroll + one scrollend,
        \\// both running in step 9 ahead of step 14 requestAnimationFrame.
        \\window.scrollTo(0, 50);
        \\window.scrollTo(0, 120);
        \\requestAnimationFrame(() => events.push('raf'));
    );
    try page.settle();
    const first = try page.evaluate("events.join(',')");
    defer testing.allocator.free(first);
    try testing.expectEqualStrings(
        "doc:scroll:true,win:scroll:true,doc:scrollend:true,win:scrollend:true,raf",
        first,
    );

    // No position change: no scroll or scrollend event fires.
    try page.run(
        \\events.length = 0;
        \\window.scrollTo(0, 120);
        \\window.scrollBy(0, 0);
        \\requestAnimationFrame(() => events.push('raf2'));
    );
    try page.settle();
    const second = try page.evaluate("events.join(',')");
    defer testing.allocator.free(second);
    try testing.expectEqualStrings("raf2", second);

    // scrollBy changing x fires scroll + scrollend again.
    try page.run(
        \\events.length = 0;
        \\window.scrollBy(25, 0);
    );
    try page.settle();
    const third = try page.evaluate("events.join(',')");
    defer testing.allocator.free(third);
    try testing.expectEqualStrings(
        "doc:scroll:true,win:scroll:true,doc:scrollend:true,win:scrollend:true",
        third,
    );
}

test "step 23: dialog.close() and hidePopover() defer top-layer removal to update the rendering" {
    try helper.onFreshThread(deferredTopLayerRemoval);
}

fn deferredTopLayerRemoval() !void {
    const page = try helper.Page.open();
    defer page.close();
    const document = page.browser.current_context.?.document_instance.?;
    try page.run(
        \\document.body.innerHTML = '<dialog id="d"></dialog><div id="p" popover></div>';
        \\const d = document.getElementById('d');
        \\const p = document.getElementById('p');
        \\d.showModal();
        \\if (!d.matches(':modal')) throw Error('dialog must be modal');
        \\d.close();
        \\if (d.open) throw Error('dialog must not have open after close');
        \\if (d.matches(':modal')) throw Error('dialog must stop matching :modal immediately');
        \\p.showPopover();
        \\if (!p.matches(':popover-open')) throw Error('popover must be open');
        \\p.hidePopover();
        \\if (p.matches(':popover-open')) throw Error('popover must stop matching :popover-open immediately');
    );
    const dialog = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("d"))).?;
    const popover = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("p"))).?;
    const layer = (try dom.top_layer.ofDocument(document, false)).?;

    // Before the next rendering opportunity: still in doc's top layer (pending removal).
    try testing.expect(!dom.dialog.isModal(dialog));
    try testing.expect(!dom.top_layer.showing(popover));
    try testing.expect(layer.inTopLayer(dialog));
    try testing.expect(layer.inTopLayer(popover));

    // After the rendering opportunity: step 23 removes both.
    try page.settle();
    try testing.expect(!layer.inTopLayer(dialog));
    try testing.expect(!layer.inTopLayer(popover));
}

test "step 23: active overlay transition keeps element in top layer across frames until overlay becomes none" {
    try helper.onFreshThread(overlayTransitionKeepsTopLayer);
}

fn overlayTransitionKeepsTopLayer() !void {
    const page = try helper.Page.open();
    defer page.close();
    const document = page.browser.current_context.?.document_instance.?;
    try page.run(
        \\const style = document.createElement('style');
        \\style.textContent = '#p { display: block; transition: overlay 60s step-end; transition-behavior: allow-discrete; }';
        \\document.head.appendChild(style);
        \\document.body.innerHTML = '<div id="p" popover></div>';
        \\const p = document.getElementById('p');
        \\p.showPopover();
        \\if (getComputedStyle(p).overlay !== 'auto') throw Error('expected overlay: auto when open');
        \\p.hidePopover();
        \\if (p.matches(':popover-open')) throw Error('must not match :popover-open');
        \\if (getComputedStyle(p).overlay !== 'auto') throw Error('expected overlay: auto during transition');
        \\globalThis.frameRan = false;
        \\requestAnimationFrame(() => { frameRan = true; });
    );
    const popover = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("p"))).?;
    const layer = (try dom.top_layer.ofDocument(document, false)).?;
    try testing.expect(layer.inTopLayer(popover));

    // Run one rendering frame while the 60s overlay transition is active:
    // computed overlay is still 'auto' and element is rendered, so step 23 must keep it.
    var spins: usize = 0;
    while (spins < 50) : (spins += 1) {
        _ = try page.browser.runEventLoopBlocking(25);
        const done = try page.evaluate("String(frameRan)");
        defer testing.allocator.free(done);
        if (std.mem.eql(u8, done, "true")) break;
    }
    const overlay_after_frame = try page.evaluate("getComputedStyle(document.getElementById('p')).overlay");
    defer testing.allocator.free(overlay_after_frame);
    try testing.expectEqualStrings("auto", overlay_after_frame);
    try testing.expect(layer.inTopLayer(popover));

    // Making the element display: none (not rendered) lets step 23 remove it immediately on the next frame.
    try page.run("document.getElementById('p').style.display = 'none';");
    try page.settle();
    try testing.expect(!layer.inTopLayer(popover));
}

test "step 23: re-opening or DOM removal while pending removal handles top layer cleanly" {
    try helper.onFreshThread(reopenAndRemoveWhilePending);
}

fn reopenAndRemoveWhilePending() !void {
    const page = try helper.Page.open();
    defer page.close();
    const document = page.browser.current_context.?.document_instance.?;
    try page.run(
        \\document.body.innerHTML = '<dialog id="d1"></dialog><dialog id="d2"></dialog><div id="p1" popover="manual"></div><div id="p2" popover="manual"></div>';
        \\const d1 = document.getElementById('d1');
        \\const d2 = document.getElementById('d2');
        \\const p1 = document.getElementById('p1');
        \\const p2 = document.getElementById('p2');
        \\// Re-open before frame: pending removal is stripped, fresh active entry stays.
        \\d1.showModal();
        \\d1.close();
        \\d1.showModal();
        \\p1.showPopover();
        \\p1.hidePopover();
        \\p1.showPopover();
        \\// Remove from DOM while pending removal: removed from top layer immediately.
        \\d2.showModal();
        \\d2.close();
        \\d2.remove();
        \\p2.showPopover();
        \\p2.hidePopover();
        \\p2.remove();
    );
    const d1 = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("d1"))).?;
    const p1 = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("p1"))).?;
    const layer = (try dom.top_layer.ofDocument(document, false)).?;
    try testing.expectEqual(@as(usize, 2), layer.entries.items.len);
    try testing.expect(layer.inTopLayer(d1));
    try testing.expect(layer.inTopLayer(p1));
    try page.settle();
    try testing.expect(dom.dialog.isModal(d1));
    try testing.expect(dom.top_layer.showing(p1));
    try testing.expect(layer.inTopLayer(d1));
    try testing.expect(layer.inTopLayer(p1));
}

test "step 13: canvas context lost resets state, restores unless canceled, and runs before rAF" {
    try helper.onFreshThread(canvasContextLostSteps);
}

fn canvasContextLostSteps() !void {
    const page = try helper.Page.open();
    defer page.close();
    const document = page.browser.current_context.?.document_instance.?;
    try page.run(
        \\document.body.innerHTML = '<canvas id="c1" width="10" height="10"></canvas><canvas id="c2" width="10" height="10"></canvas>';
        \\globalThis.log = [];
        \\const c1 = document.getElementById('c1');
        \\const ctx1 = c1.getContext('2d');
        \\ctx1.fillStyle = '#ff0000';
        \\ctx1.lineWidth = 7;
        \\c1.addEventListener('contextlost', (e) => {
        \\  log.push('c1:lost:' + e.cancelable + ':' + ctx1.isContextLost() + ':' + ctx1.fillStyle + ':' + ctx1.lineWidth);
        \\});
        \\c1.addEventListener('contextrestored', (e) => {
        \\  log.push('c1:restored:' + e.cancelable + ':' + ctx1.isContextLost());
        \\});
        \\// Second canvas cancels restoration via preventDefault().
        \\const c2 = document.getElementById('c2');
        \\const ctx2 = c2.getContext('2d');
        \\ctx2.fillStyle = '#00ff00';
        \\c2.addEventListener('contextlost', (e) => {
        \\  e.preventDefault();
        \\  log.push('c2:lost:' + ctx2.isContextLost() + ':' + ctx2.fillStyle);
        \\});
        \\c2.addEventListener('contextrestored', () => log.push('c2:restored:UNEXPECTED'));
        \\requestAnimationFrame(() => log.push('raf:c1=' + ctx1.isContextLost() + ',c2=' + ctx2.isContextLost()));
    );
    const c1 = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("c1"))).?;
    const c2 = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("c2"))).?;
    const ctx1_val = (try interfaces.HTMLCanvasElement.call_getContext(c1, runtime.DOMString.initInterned("2d"), .notPassed())).?;
    const ctx2_val = (try interfaces.HTMLCanvasElement.call_getContext(c2, runtime.DOMString.initInterned("2d"), .notPassed())).?;
    dom.canvas_2d.markContextLost(document, ctx1_val.canvas_rendering_context2d);
    dom.canvas_2d.markContextLost(document, ctx2_val.canvas_rendering_context2d);

    try page.settle();
    const out = try page.evaluate("log.join('|')");
    defer testing.allocator.free(out);
    try testing.expectEqualStrings(
        "c1:lost:true:true:#000000:1|c1:restored:false:false|c2:lost:true:#000000|raf:c1=false,c2=true",
        out,
    );
}

test "steps 9/13/20/21/23: idle rendering opportunities allocate no lazy state" {
    try helper.onFreshThread(idleStepsAreLazy);
}

fn idleStepsAreLazy() !void {
    const page = try helper.Page.open();
    defer page.close();
    const document = page.browser.current_context.?.document_instance.?;
    try page.run("requestAnimationFrame(() => {});");
    try page.settle();

    const scope = runtime.BrowserScope.ofInstance(document);
    try testing.expect(scope.existing(dom.scroll_events.Pending) == null);
    try testing.expect(scope.existing(dom.canvas_2d.PendingLost) == null);
    try testing.expect(scope.existing(dom.frame_timing.State) == null);
    try testing.expect((try dom.top_layer.ofDocument(document, false)) == null);
}

test "steps 20 & 21: rendering time filters <50ms frames and hands >=50ms frames to markPaintTiming" {
    try helper.onFreshThread(frameTimingAndPaintTimingSteps);
}

fn frameTimingAndPaintTimingSteps() !void {
    const page = try helper.Page.open();
    defer page.close();
    const document = page.browser.current_context.?.document_instance.?;
    const platform = @import("platform");

    // Paint timing stays out of supportedEntryTypes while headless (needs-renderer).
    const has_paint = try page.evaluate("String(PerformanceObserver.supportedEntryTypes.includes('paint'))");
    defer testing.allocator.free(has_paint);
    try testing.expectEqualStrings("false", has_paint);

    // 1. Short frame (<50ms): step 20 drops current frame timing info, records nothing.
    const now_ns: i64 = @intCast(platform.monotonicNow().ns);
    dom.frame_timing.recordTaskStartTime(document, now_ns);
    try testing.expect(dom.frame_timing.hasActiveFrameTimingInfo(document));
    try page.run("requestAnimationFrame(() => {});");
    try page.settle();
    try testing.expect(!dom.frame_timing.hasActiveFrameTimingInfo(document));
    try testing.expectEqual(@as(usize, 0), dom.frame_timing.completedFrames(document).len);

    // 2. Long frame (>=50ms) on top-level (paint-timing eligible) document:
    //    step 15 sets style_and_layout_start_ns, step 20 accumulates periods
    //    starting at/after style_and_layout_start_ns, and step 21 completes
    //    with PaintTimingInfo (presentation_time == null).
    const long_start_ns = @as(i64, @intCast(platform.monotonicNow().ns)) - 100 * std.time.ns_per_ms;
    dom.frame_timing.recordTaskStartTime(document, long_start_ns);
    // Period before style-and-layout start must be ignored; a period far in the
    // future (relative ms > style_and_layout_start) must be accumulated.
    dom.frame_timing.recordStyleOrLayoutPeriod(document, .style, 0.0, 2.0);
    dom.frame_timing.recordStyleOrLayoutPeriod(document, .style, 1.0e15, 1.0e15 + 3.5);
    try page.run("requestAnimationFrame(() => {});");
    try page.settle();

    try testing.expect(!dom.frame_timing.hasActiveFrameTimingInfo(document));
    const completed = dom.frame_timing.completedFrames(document);
    try testing.expectEqual(@as(usize, 1), completed.len);
    try testing.expectEqual(long_start_ns, completed[0].start_time_ns);
    try testing.expect(completed[0].style_and_layout_start_time_ns > 0);
    try testing.expectApproxEqAbs(@as(f64, 3.5), completed[0].style_duration_ms, 0.001);
    try testing.expect(completed[0].paint.presentation_time == null);
    try testing.expect(completed[0].paint.rendering_update_end_time >= 0);
}
