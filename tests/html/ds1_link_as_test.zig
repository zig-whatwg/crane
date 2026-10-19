//! Browser-majority reflection of the link as attribute (row 86 Q5).
const helpers = @import("edges_node_holders_helpers.zig");

fn reflectDestinations() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const link = document.createElement('link');
        \\for (const rel of ['', 'preload', 'modulepreload']) {
        \\  link.rel = rel;
        \\  for (const value of ['fetch', 'font', 'image', 'script', 'style', 'track']) {
        \\    link.as = value.toUpperCase();
        \\    if (link.as !== value) throw new Error('known destination not canonicalized: ' + value);
        \\    if (link.getAttribute('as') !== value.toUpperCase()) throw new Error('raw attribute changed');
        \\  }
        \\  for (const value of ['audio', 'audioworklet', 'document', 'embed', 'frame', 'iframe',
        \\      'json', 'manifest', 'object', 'paintworklet', 'report', 'serviceworker',
        \\      'sharedworker', 'text', 'video', 'webidentity', 'worker', 'xslt', ' image', 'image ']) {
        \\    link.as = value;
        \\    if (link.as !== '') throw new Error('unsupported destination reflected: ' + value);
        \\    if (link.getAttribute('as') !== value) throw new Error('raw unsupported value changed');
        \\  }
        \\  link.removeAttribute('as');
        \\  if (link.as !== '') throw new Error('missing as did not reflect empty string');
        \\}
    );
}

test "link as reflects the six browser-majority destinations without changing raw attributes" {
    try helpers.onFreshThread(reflectDestinations);
}
