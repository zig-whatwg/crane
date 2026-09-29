//! HTML "load a document"'s branch table and the markup a text or media
//! document is made from (html_core.navigation.document_type) - shared by the
//! top-level page (src/browser) and every navigable container.
//! Spec: https://html.spec.whatwg.org/multipage/document-lifecycle.html#loading-a-document

const std = @import("std");
const testing = std.testing;
const document_type = @import("html_core").navigation.document_type;

test "a top-level text/plain response is a text document, not HTML" {
    const essence = try document_type.essence(testing.allocator, "text/plain; charset=utf-8");
    defer testing.allocator.free(essence);
    try testing.expectEqual(document_type.DocumentClass.text, document_type.classify(essence));
}

test "a text document's markup is one pre whose text is the response, inert" {
    const markup = try document_type.textDocumentMarkup(testing.allocator, "a <b>&c</b>\n\"q\" > r");
    defer testing.allocator.free(markup);
    try testing.expectEqualStrings("<pre>\na &lt;b>&amp;c&lt;/b>\n\"q\" > r</pre>", markup);
}

test "a media document hosts the resource in img, video or audio" {
    const img = try document_type.mediaDocumentMarkup(testing.allocator, "https://a.test/x.png?a=1&b=\"2\"", .img);
    defer testing.allocator.free(img);
    try testing.expectEqualStrings("<img src=\"https://a.test/x.png?a=1&amp;b=&quot;2&quot;\">", img);
    const video = try document_type.mediaDocumentMarkup(testing.allocator, "https://a.test/v.webm", .video);
    defer testing.allocator.free(video);
    try testing.expectEqualStrings("<video src=\"https://a.test/v.webm\" controls></video>", video);
}
