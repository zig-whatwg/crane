//! Fetch "data: URL processor" (Fetch 6), steps 11-14: the base64 marker may
//! have spaces after its ";", and the MIME type is PARSED - a type that does
//! not parse is text/plain;charset=US-ASCII, and the struct's MIME type is a
//! MIME type record, which scheme fetch "data" serializes into the response's
//! `Content-Type`. All three browsers agree (lane core1 b7 probe, 2026-11-24:
//! Chrome 157, Firefox 159, Safari 27.0 run `data:text/javascript; base64,...`
//! as a module worker and refuse `data:javascript,...` as one).

const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");

const processDataUrl = fetch.algorithms.processDataUrl;

fn expectDataUrl(url: []const u8, mime_type: []const u8, body: []const u8) !void {
    var result = (try processDataUrl(testing.allocator, url)).?;
    defer result.deinit();
    try testing.expectEqualStrings(mime_type, result.mime_type);
    try testing.expectEqualStrings(body, result.body);
}

// "cG9zdE1lc3NhZ2UoJ29rJyk=" is "postMessage('ok')".

test "step 11: spaces between the ';' and 'base64' still mark a base64 body" {
    try expectDataUrl("data:text/javascript; base64,cG9zdE1lc3NhZ2UoJ29rJyk=", "text/javascript", "postMessage('ok')");
    try expectDataUrl("data:text/javascript;   BASE64,cG9zdE1lc3NhZ2UoJ29rJyk=", "text/javascript", "postMessage('ok')");
}

test "step 11: a space before the ';' is the MIME type's, which parsing strips" {
    try expectDataUrl("data:text/javascript ;base64,cG9zdE1lc3NhZ2UoJ29rJyk=", "text/javascript", "postMessage('ok')");
}

test "step 11: 'base64' anywhere but the end of the type is not the marker" {
    // (Parsing drops the parameter with no "=": MIME Sniffing "parse a MIME
    // type" step 11.)
    try expectDataUrl("data:text/javascript;base64;charset=utf-8,cG9zdE1lc3NhZ2UoJ29rJyk=", "text/javascript;charset=utf-8", "cG9zdE1lc3NhZ2UoJ29rJyk=");
    try expectDataUrl("data:text/javascript;enc=base64,cG9zdE1lc3NhZ2UoJ29rJyk=", "text/javascript;enc=base64", "cG9zdE1lc3NhZ2UoJ29rJyk=");
}

test "steps 13-14: a MIME type that does not parse is text/plain;charset=US-ASCII" {
    try expectDataUrl("data:javascript,x", "text/plain;charset=US-ASCII", "x");
    try expectDataUrl("data:text/javascript foo,x", "text/plain;charset=US-ASCII", "x");
    try expectDataUrl("data:text/,x", "text/plain;charset=US-ASCII", "x");
}

test "step 13: the MIME type is a parsed record - lowercased type, normalized parameters" {
    try expectDataUrl("data:TEXT/JavaScript,x", "text/javascript", "x");
    try expectDataUrl("data:text/plain;Charset=\"utf-8\";charset=x,x", "text/plain;charset=utf-8", "x");
    try expectDataUrl("data:text/plain;a=\"b c\",x", "text/plain;a=\"b c\"", "x");
}

test "scheme fetch data: the response's Content-Type is the MIME type serialized" {
    const result = try fetch.algorithms.scheme_fetch.schemeFetch(testing.allocator, "data", "data:Text/Plain;base64 ,aGk=");
    const response = switch (result) {
        .response => |response| response,
        .network_error => return error.TestUnexpectedResult,
    };
    defer response.deinit();
    try testing.expectEqualStrings("text/plain", response.header_list.getFirstValue("content-type").?);
}
