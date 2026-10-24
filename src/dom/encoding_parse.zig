//! HTML "encoding-parse a URL" and "encoding-parse-and-serialize a URL",
//! relative to a Document: the URL parser run against the document's base
//! URL with the document's character encoding, which the query is
//! percent-encoded with.
//!
//! Spec: https://html.spec.whatwg.org/multipage/urls-and-fetching.html#encoding-parsing-a-url
//!
//! The one place impls and the rest of html encoding-parse a document's
//! URLs: reflected URL attributes, a and area's url, the meta refresh URL;
//! and a worker's, relative to its API base URL in UTF-8, for the Worker and
//! SharedWorker constructors.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const api_parser = @import("api_parser");
const sniffing = @import("html_core").parser.encoding_sniffing;

/// "Encoding-parse-and-serialize a URL" given `input`, relative to `node`'s
/// node document (`node` itself when it is a Document): the serialized URL,
/// owned by `node.ctx.allocator`, or null for failure.
pub fn encodingParseAndSerialize(node: *runtime.Instance, input: []const u8) error{OutOfMemory}!?[]const u8 {
    return encodingParseAndSerializeWithAllocator(node.ctx.allocator, node, input);
}

/// The same document-relative algorithm with parsing and returned-string
/// storage owned by `allocator`. A call-local allocator is valid only while
/// the returned URL is borrowed; copy it before a task or cache retains it.
pub fn encodingParseAndSerializeWithAllocator(allocator: std.mem.Allocator, node: *runtime.Instance, input: []const u8) error{OutOfMemory}!?[]const u8 {
    // Step 4: the document base URL, which Node's baseURI serializes.
    const base = interfaces.Node.get_baseURI(node) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => "",
    };
    defer if (base.len > 0) node.ctx.allocator.free(base);
    // Steps 1-2 and 5.
    return api_parser.encodingParseAndSerialize(allocator, input, base, documentEncoding(node));
}

/// "Encoding-parse-and-serialize a URL" given `input`, relative to a worker's
/// settings object: against its API base URL `api_base_url` (none when null,
/// or when it does not parse), the query encoded with its API URL character
/// encoding, which is UTF-8. The Worker and SharedWorker constructors' script
/// URL, when the outside settings are a worker's ("Let workerURL be the
/// result of encoding-parsing a URL given compliantScriptURL, relative to
/// outsideSettings"). OWNED by `allocator`; SyntaxError for failure.
pub fn encodingParseAndSerializeUtf8(allocator: std.mem.Allocator, input: []const u8, api_base_url: ?[]const u8) error{ SyntaxError, OutOfMemory }![]const u8 {
    return (try api_parser.encodingParseAndSerialize(allocator, input, api_base_url, sniffing.utf_8)) orelse error.SyntaxError;
}

/// Steps 1-2: the character encoding of `node`'s node document, UTF-8 when
/// its name is not an encoding's.
fn documentEncoding(node: *runtime.Instance) sniffing.Encoding {
    const document = (interfaces.Node.get_ownerDocument(node) catch null) orelse node;
    var name = interfaces.Document.get_characterSet(document) catch return sniffing.utf_8;
    defer name.deinit(document.ctx.allocator);
    return sniffing.lookup(name.asSlice()) orelse sniffing.utf_8;
}
