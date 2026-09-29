//! The request HTML's script fetches build: a crossorigin attribute's CORS
//! settings state, and "create a potential-CORS request".
//!
//! Spec: https://html.spec.whatwg.org/multipage/urls-and-fetching.html#cors-settings-attributes
//! Spec: https://html.spec.whatwg.org/multipage/urls-and-fetching.html#create-a-potential-cors-request

const std = @import("std");
const testing = std.testing;

const html = @import("html");
const script_request = html.script_request;

test "a crossorigin attribute: missing is No CORS, use-credentials is Use Credentials, anything else Anonymous" {
    try testing.expectEqual(script_request.CorsSetting.no_cors, script_request.corsSettingFromAttribute(null));
    try testing.expectEqual(script_request.CorsSetting.anonymous, script_request.corsSettingFromAttribute(""));
    try testing.expectEqual(script_request.CorsSetting.anonymous, script_request.corsSettingFromAttribute("anonymous"));
    try testing.expectEqual(script_request.CorsSetting.anonymous, script_request.corsSettingFromAttribute("bogus"));
    try testing.expectEqual(script_request.CorsSetting.use_credentials, script_request.corsSettingFromAttribute("USE-Credentials"));
}

test "a potential-CORS request: no-cors and include without CORS, cors and same-origin for Anonymous, cors and include for Use Credentials" {
    const Request = script_request.InternalRequest;
    const Case = struct { cors: script_request.CorsSetting, mode: @FieldType(Request, "mode"), credentials: @FieldType(Request, "credentials_mode") };
    const cases = [_]Case{
        .{ .cors = .no_cors, .mode = .no_cors, .credentials = .include },
        .{ .cors = .anonymous, .mode = .cors, .credentials = .same_origin },
        .{ .cors = .use_credentials, .mode = .cors, .credentials = .include },
    };
    for (cases) |case| {
        const request = try Request.init(testing.allocator, "https://example.com/a.js");
        defer request.deinit();
        script_request.createPotentialCorsRequest(request, .script, case.cors);
        try testing.expectEqual(case.mode, request.mode);
        try testing.expectEqual(case.credentials, request.credentials_mode);
        try testing.expectEqual(@as(@FieldType(Request, "destination"), .script), request.destination);
        try testing.expect(request.use_url_credentials);
    }
}
