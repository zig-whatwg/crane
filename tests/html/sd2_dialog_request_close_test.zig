//! Request-only dialog payloads are scoped across cancel-event reentrancy.
const helpers = @import("edges_node_holders_helpers.zig");
const dom = @import("dom");
const html = @import("html");

fn reentrantRequest() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const dialog = document.body.appendChild(document.createElement('dialog'));
        \\dialog.show();
        \\dialog.addEventListener('cancel', () => {
        \\  dialog.requestClose('inner');
        \\  collectNow();
        \\}, {once: true});
        \\dialog.requestClose('outer');
        \\if (dialog.open || dialog.returnValue !== 'outer') throw new Error('reentrant request overwrote the active result');
    );
}

fn canceledPayload() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<button id=outside>outside</button><dialog id=d closedby=any><button command=request-close commandfor=d>request</button></dialog>';
        \\const dialog = document.getElementById('d');
        \\dialog.returnValue = 'preserved';
        \\dialog.show();
    );
    try page.turn();
    try page.run(
        \\dialog.addEventListener('cancel', event => event.preventDefault(), {once: true});
        \\dialog.querySelector('button').click();
        \\if (!dialog.open) throw new Error('canceled request closed');
        \\globalThis.closedSource = 'unfired';
        \\dialog.addEventListener('toggle', event => closedSource = event.source, {once: true});
    );
    const document = page.browser.current_context.?.document_instance.?;
    const outside = (try dom.selector_matching.querySelector(document, "#outside")).?;
    var pointer: html.user_input.Pointer = .{};
    html.user_input.pointerMove(&pointer, outside, .{});
    html.user_input.pointerDown(&pointer, 0, .{});
    html.user_input.pointerUp(&pointer, 0, .{});
    try page.turn();
    try page.run("if (dialog.open || dialog.returnValue !== 'preserved' || closedSource !== null) throw new Error('canceled payload leaked into light dismiss')");
}

test "reentrant requestClose preserves the active result through collection" {
    try helpers.onFreshThread(reentrantRequest);
}

test "canceled requests supply no result or source to subsequent light dismiss" {
    try helpers.onFreshThread(canceledPayload);
}
