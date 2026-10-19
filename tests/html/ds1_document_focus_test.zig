//! Document.hasFocus follows the focused document chain through iframes.
const helpers = @import("edges_node_holders_helpers.zig");

fn focusedDocuments() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.ds1Frame = document.createElement('iframe');
        \\document.body.append(ds1Frame);
    );
    try page.turn();
    try page.run(
        \\const child = ds1Frame.contentDocument;
        \\if (!child) throw new Error('iframe did not create a document');
        \\if (child.hasFocus()) throw new Error('unfocused iframe reports focus');
        \\if (!document.hasFocus()) throw new Error('top document lost system focus');
        \\const button = child.createElement('button');
        \\child.body.append(button);
        \\button.focus();
        \\if (!child.hasFocus()) throw new Error('focused iframe reports no focus');
        \\if (!document.hasFocus()) throw new Error('ancestor of focused iframe reports no focus');
        \\const outside = document.createElement('button');
        \\document.body.append(outside);
        \\outside.focus();
        \\if (child.hasFocus()) throw new Error('iframe retains focus after focus moves out');
        \\ds1Frame.remove();
        \\outside.remove();
    );
}

test "Document.hasFocus follows focus into and out of a child document" {
    try helpers.onFreshThread(focusedDocuments);
}

fn documentsWithoutNavigables() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\for (const doc of [new Document(), document.implementation.createHTMLDocument(''),
        \\    new DOMParser().parseFromString('<root/>', 'text/xml')]) {
        \\  if (doc.hasFocus()) throw new Error('document without a navigable reports focus');
        \\}
    );
}

test "Document.hasFocus is false without a browsing context" {
    try helpers.onFreshThread(documentsWithoutNavigables);
}
