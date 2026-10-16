//! HTML 8.1.3.5 "secure context", for a Window's and a worker's environment
//! settings object - as the browsers decide it.
//!
//! The spec text decides from the environment's top-level creation URL alone
//! (Secure Contexts 3.2 "Is url potentially trustworthy?") and, for a worker,
//! from its owner. The browsers also look at the document itself and at
//! every ancestor, so an https: frame inside an http: page is NOT a secure
//! context and neither is an http: frame inside an https: one (golden rule
//! 2: browsers decide):
//!
//! - WebKit, Source/WebCore/dom/Document.cpp: `computeIsSecureContext` is
//!   "the parent frame's document is a secure context, and isDocumentSecure"
//!   - the document's own origin is potentially trustworthy (its URL's
//!   trustworthiness when it is sandboxed into an opaque origin) - and a
//!   document whose URL inherits its origin from its owner (about:blank,
//!   about:srcdoc) copies `m_isSecureContext` from the owner: its parent,
//!   else its opener (`Document::initSecurityContext`).
//! - Blink, third_party/blink/renderer/core/execution_context/
//!   security_context.cc `SecurityContext::SetSecurityOrigin`: insecure when
//!   the origin is not potentially trustworthy, or when
//!   `LocalDOMWindow::HasInsecureContextInAncestors` finds an ancestor frame
//!   whose origin is not; the opaque origin of an inheriting or sandboxed
//!   document carries its owner's (or URL's) trustworthiness
//!   (core/loader/document_loader.cc, `SetOpaqueOriginIsPotentiallyTrustworthy`).
//!
//! wpt.fyi (2026-10-16, stable): secure-contexts/basic-popup-and-iframe-tests.html
//! 20/20 in Chrome, Firefox and Safari; the .https.html 16, 18 and 17 of 18;
//! basic-dedicated-worker.html and .https.html 7/7 in all three. A data:
//! frame follows its parent (Secure Contexts 3.2 step 2 trusts its URL).

const std = @import("std");
const mixed_content = @import("fetch").mixed_content;

/// Whether a document at `url` takes its secure context from the one that
/// created it: about:blank (and the initial empty URL) and about:srcdoc, as
/// WebKit's SecurityPolicy::shouldInheritSecurityOriginFromOwner, plus a
/// javascript: URL's result document, whose URL is its creator's anyway.
pub fn inheritsFromCreator(url: []const u8) bool {
    if (url.len == 0) return true;
    if (std.ascii.startsWithIgnoreCase(url, "javascript:")) return true;
    if (!std.ascii.startsWithIgnoreCase(url, "about:")) return false;
    // "about:blank" and "about:srcdoc", with any query or fragment.
    const rest = url["about:".len..];
    const end = std.mem.indexOfAny(u8, rest, "?#") orelse rest.len;
    const path = rest[0..end];
    return std.mem.eql(u8, path, "blank") or std.mem.eql(u8, path, "srcdoc");
}

/// What decides a Window's answer: its document's URL, and the answers of
/// the environments it depends on.
pub const Document = struct {
    /// The document's URL.
    url: []const u8,
    /// The parent navigable's active document's answer; null for a
    /// top-level traversable.
    parent: ?bool,
    /// The creator's answer, for a document that inherits it
    /// (`inheritsFromCreator`) and has no parent: a popup's opener. Null
    /// when there was none.
    creator: ?bool,
};

/// Is a Window whose document is `document` a secure context?
pub fn ofDocument(allocator: std.mem.Allocator, document: Document) error{OutOfMemory}!bool {
    // about:blank and about:srcdoc: the creator's answer - the parent's, else
    // the opener's. With neither, the spec's own answer: its top-level
    // creation URL is about:blank, which is potentially trustworthy.
    if (inheritsFromCreator(document.url)) return document.parent orelse document.creator orelse true;
    // Secure Contexts 3.2 on the document's own URL (data: is trustworthy;
    // a blob: URL's origin is its creator's).
    if (!try mixed_content.isAPrioriAuthenticated(allocator, document.url)) return false;
    // ...and its parent is a secure context.
    return document.parent orelse true;
}

/// Is a worker global scope whose URL is `url` and whose owner (owner set[0]'s
/// relevant settings object) answered `owner` a secure context? HTML 8.1.3.5
/// step 1.2 takes the owner's answer; like Blink (a worker's
/// starter_secure_context together with its own origin), the worker's own URL
/// must be potentially trustworthy too - a data: script's is.
pub fn ofWorker(allocator: std.mem.Allocator, url: []const u8, owner: bool) error{OutOfMemory}!bool {
    if (!owner) return false;
    return mixed_content.isAPrioriAuthenticated(allocator, url);
}

test "a document's own URL and its parent decide" {
    const a = std.testing.allocator;
    try std.testing.expect(!try ofDocument(a, .{ .url = "http://example.com/", .parent = null, .creator = null }));
    try std.testing.expect(try ofDocument(a, .{ .url = "https://example.com/", .parent = null, .creator = null }));
    try std.testing.expect(try ofDocument(a, .{ .url = "http://localhost:8000/", .parent = null, .creator = null }));
    try std.testing.expect(try ofDocument(a, .{ .url = "http://127.0.0.1/", .parent = null, .creator = null }));
    try std.testing.expect(try ofDocument(a, .{ .url = "file:///a.html", .parent = null, .creator = null }));
    // https: in http: is not; http: in https: is not.
    try std.testing.expect(!try ofDocument(a, .{ .url = "https://example.com/", .parent = false, .creator = null }));
    try std.testing.expect(!try ofDocument(a, .{ .url = "http://example.com/", .parent = true, .creator = null }));
    try std.testing.expect(try ofDocument(a, .{ .url = "https://example.com/", .parent = true, .creator = null }));
    // data: follows its parent; blob: its creator's origin, and its parent.
    try std.testing.expect(!try ofDocument(a, .{ .url = "data:text/html,x", .parent = false, .creator = null }));
    try std.testing.expect(try ofDocument(a, .{ .url = "data:text/html,x", .parent = true, .creator = null }));
    try std.testing.expect(!try ofDocument(a, .{ .url = "blob:http://example.com/uuid", .parent = null, .creator = null }));
    try std.testing.expect(try ofDocument(a, .{ .url = "blob:https://example.com/uuid", .parent = null, .creator = null }));
}

test "about:blank and about:srcdoc take their creator's answer" {
    const a = std.testing.allocator;
    for ([_][]const u8{ "about:blank", "about:srcdoc", "", "about:blank#x", "about:blank?y" }) |url| {
        try std.testing.expect(!try ofDocument(a, .{ .url = url, .parent = false, .creator = null }));
        try std.testing.expect(try ofDocument(a, .{ .url = url, .parent = true, .creator = null }));
        try std.testing.expect(!try ofDocument(a, .{ .url = url, .parent = null, .creator = false }));
        try std.testing.expect(try ofDocument(a, .{ .url = url, .parent = null, .creator = true }));
        // The parent wins over an opener.
        try std.testing.expect(!try ofDocument(a, .{ .url = url, .parent = false, .creator = true }));
        // Neither: about:blank is potentially trustworthy.
        try std.testing.expect(try ofDocument(a, .{ .url = url, .parent = null, .creator = null }));
    }
    // Another about: URL has an opaque origin: not trustworthy.
    try std.testing.expect(!inheritsFromCreator("about:config"));
    try std.testing.expect(!try ofDocument(a, .{ .url = "about:config", .parent = null, .creator = true }));
}

test "a worker takes its owner's answer, and its own URL's" {
    const a = std.testing.allocator;
    try std.testing.expect(!try ofWorker(a, "http://example.com/w.js", false));
    try std.testing.expect(!try ofWorker(a, "https://example.com/w.js", false));
    try std.testing.expect(!try ofWorker(a, "data:text/javascript,x", false));
    try std.testing.expect(try ofWorker(a, "data:text/javascript,x", true));
    try std.testing.expect(try ofWorker(a, "https://example.com/w.js", true));
    try std.testing.expect(try ofWorker(a, "blob:https://example.com/uuid", true));
    try std.testing.expect(!try ofWorker(a, "http://example.com/w.js", true));
}
