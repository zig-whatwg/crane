//! Q54: lazy document seed, scalar element identity, and synchronous borrowing.
const std = @import("std");
const dom = @import("dom");
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const testing = std.testing;
const helper = @import("edges_node_holders_helpers.zig");

test "document random input is lazy and stable across style reads and adoption" {
    try helper.onFreshThread(stability);
}

fn stability() !void {
    if (comptime !@hasField(dom.style.StyleEngine.Rare, "random_seed")) return error.RandomDocumentProviderNotImplemented;
    const page = try helper.Page.open();
    defer page.close();
    const document = page.browser.current_context.?.document_instance.?;
    const engine = dom.style.hooks.engineOf(document).?;
    try testing.expect(engine.rare == null);
    try page.run(
        \\document.body.innerHTML = '<div id="random-target"></div>';
        \\globalThis.target = document.getElementById('random-target');
        \\getComputedStyle(target).left;
        \\target.style.left = 'random(fixed .5,0px,100px)';
        \\if (getComputedStyle(target).left !== '50px') throw Error('fixed draw');
    );
    try testing.expect(engine.rare == null);
    try page.run(
        \\target.style.left = 'random(element-scoped,0px,1000000px)';
        \\globalThis.original = getComputedStyle(target).left;
        \\if (original === 'auto') throw Error('random unavailable');
        \\target.style.color = 'red';
        \\if (getComputedStyle(target).left !== original) throw Error('recalculation reseeded');
        \\target.remove(); document.body.append(target);
        \\if (getComputedStyle(target).left !== original) throw Error('reattachment reseeded');
        \\const sheet = document.createElement('style');
        \\sheet.textContent = '#random-target::before { content:"x"; left:random(element-scoped,0px,1000000px) }';
        \\document.head.append(sheet);
        \\if (getComputedStyle(target,'::before').left === original) throw Error('pseudo shares element identity');
        \\const frame = document.createElement('iframe'); document.body.append(frame);
        \\frame.contentDocument.body.append(target);
        \\if (frame.contentWindow.getComputedStyle(target).left === original) throw Error('adoption shares document seed');
        \\document.body.append(target);
        \\if (getComputedStyle(target).left !== original) throw Error('return lost original mapping');
        \\frame.remove();
    );
    const seed = engine.rare.?.random_seed orelse return error.NoRandomSeed;
    try page.run("target.style.color = 'blue'; getComputedStyle(target).left;");
    try testing.expectEqual(seed, engine.rare.?.random_seed.?);
}

test "random document seed allocation failure propagates without a fallback draw" {
    try helper.onFreshThread(allocationFailure);
}

fn allocationFailure() !void {
    if (comptime !@hasField(dom.style.StyleEngine.Rare, "random_seed")) return error.RandomDocumentProviderNotImplemented;
    const page = try helper.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<div id="random-oom"></div>';
        \\getComputedStyle(document.getElementById('random-oom')).left;
        \\document.getElementById('random-oom').style.left = 'random(1px,10px)';
    );
    const document = page.browser.current_context.?.document_instance.?;
    const engine = dom.style.hooks.engineOf(document).?;
    const target = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("random-oom"))).?;
    try testing.expect(engine.rare == null);
    // Only Rare uses this allocator during the resolution. Node and value
    // allocations keep their own allocator, so the failure names this seam.
    const original_allocator = engine.allocator;
    var failing = testing.FailingAllocator.init(original_allocator, .{ .fail_index = 0 });
    engine.allocator = failing.allocator();
    defer engine.allocator = original_allocator;
    try testing.expectError(error.OutOfMemory, dom.style.computedStyle(target, null));
    try testing.expect(engine.rare == null);
}
