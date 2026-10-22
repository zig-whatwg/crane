//! DOM createCDATASection step 2, including step 1 exception precedence.
const helpers = @import("edges_node_holders_helpers.zig");

fn exercise() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const xml = document.implementation.createDocument(null, 'r');
        \\function throws(name, callback) {
        \\  try { callback(); } catch (e) { if (e.name === name) return; throw e; }
        \\  throw new Error('missing ' + name);
        \\}
        \\for (const data of [']]>', 'prefix]]>suffix', 'prefix]]>']) {
        \\  throws('InvalidCharacterError', () => xml.createCDATASection(data));
        \\  throws('NotSupportedError', () => document.createCDATASection(data));
        \\}
        \\for (const data of ['', ']]', 'a]b>c']) {
        \\  const node = xml.createCDATASection(data);
        \\  if (node.ownerDocument !== xml || node.data !== data || node.nodeType !== 4) throw new Error('CDATA state');
        \\}
    );
}

test "CDATA delimiter validation preserves HTML precedence and XML node state" {
    try helpers.onFreshThread(exercise);
}
