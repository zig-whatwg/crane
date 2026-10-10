//! Shared by the od_*_test.zig files (lane ownerdoc): a page that collects,
//! lets the deferred teardown run, and reissues the freed slots, so a holder
//! that kept a bare pointer reads another object - or crashes.
const helpers = @import("edges_node_holders_helpers.zig");
pub const onFreshThread = helpers.onFreshThread;
pub const Page = helpers.Page;

/// Collect, let the deferred teardown free what was collected (it runs
/// between tasks), and collect again with the freed slots reissued.
pub fn collectAndTurn(page: Page) !void {
    try page.run("collectNow();");
    try page.turn();
    try page.run("collectNow();");
    try page.turn();
}

/// A windowless document with an expando, made in `script` as `doc`, and a
/// check that a node's document is that one, whole: `checkDocument(node,
/// what)` throws otherwise.
pub const document_check =
    \\globalThis.checkDocument = (node, what) => {
    \\  const doc = node.ownerDocument;
    \\  if (!doc || doc.nodeType !== 9) throw new Error(what + ': ownerDocument is ' + (doc && doc.nodeType));
    \\  if (doc.od !== 'od') throw new Error(what + ': another document');
    \\  if (doc.body.localName !== 'body') throw new Error(what + ': its tree went');
    \\};
    \\globalThis.makeDocument = () => {
    \\  const doc = document.implementation.createHTMLDocument('od');
    \\  doc.od = 'od';
    \\  return doc;
    \\};
;

/// Open a page with `document_check` defined.
pub fn open() !Page {
    const page = try Page.open();
    errdefer page.close();
    try page.run(document_check);
    return page;
}
