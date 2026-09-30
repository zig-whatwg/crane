//! The request HTML's script fetches build: "create a potential-CORS
//! request", and Fetch's "populate request from client" for a script's
//! settings object.
//!
//! "fetch a classic script" (script_execution.zig) and "fetch a single module
//! script" (module_script.zig) both make their requests here, so both carry
//! what Fetch keys on: the destination (main fetch step 19's MIME type and
//! nosniff checks), the mode and credentials mode (CORS), and the client's
//! origin and referrer.

const std = @import("std");
const runtime = @import("runtime");
const fetch = @import("fetch");
const global_settings = @import("dom").global_settings;

/// The request a script fetch builds.
pub const InternalRequest = fetch.internal.InternalRequest;

/// A CORS settings attribute's state.
///
/// Spec: https://html.spec.whatwg.org/multipage/urls-and-fetching.html#cors-settings-attributes
pub const CorsSetting = enum { no_cors, anonymous, use_credentials };

/// A crossorigin attribute's value as a CORS settings attribute: "The
/// attribute's missing value default is the No CORS state, and its invalid
/// value default is the Anonymous state" - the empty string is Anonymous too.
pub fn corsSettingFromAttribute(value: ?[]const u8) CorsSetting {
    const v = value orelse return .no_cors;
    if (std.ascii.eqlIgnoreCase(v, "use-credentials")) return .use_credentials;
    return .anonymous;
}

/// HTML "create a potential-CORS request", on `request` (its URL already
/// set), given a destination and a CORS setting.
///
/// Spec: https://html.spec.whatwg.org/multipage/urls-and-fetching.html#create-a-potential-cors-request
/// "1. Let mode be "no-cors" if corsAttributeState is No CORS, and "cors"
///  otherwise. 2. If same-origin fallback flag is set and mode is "no-cors",
///  set mode to "same-origin". 3. Let credentialsMode be "include". 4. If
///  corsAttributeState is Anonymous, set credentialsMode to "same-origin".
///  5. Let request be a new request whose URL is url, destination is
///  destination, mode is mode, credentials mode is credentialsMode, and whose
///  use-URL-credentials flag is set."
/// (No script fetch sets the same-origin fallback flag.)
pub fn createPotentialCorsRequest(request: *InternalRequest, destination: fetch.internal.Destination, cors: CorsSetting) void {
    request.mode = if (cors == .no_cors) .no_cors else .cors;
    request.credentials_mode = if (cors == .anonymous) .same_origin else .include;
    request.destination = destination;
    request.use_url_credentials = true;
}

/// Fetch "populate request from client" for a request whose client is the
/// settings object of `realm`'s global. `dom.global_settings.requestClient`
/// reads the client out of the global - its origin, its document's URL as the
/// referrer source, a Window's traversable, the cookie jar - and
/// `fetch.internal.populateRequestFromClient` applies it: the same pair
/// `fetch()`, XMLHttpRequest and WebSocket use, so a script's request means
/// the same thing by "the client" as theirs.
///
/// Spec: https://fetch.spec.whatwg.org/#populate-request-from-client
pub fn populateRequestFromClient(request: *InternalRequest, realm: runtime.Context) !void {
    const global = globalOfRealm(realm) orelse return;
    var client = try global_settings.requestClient(global);
    defer client.deinit();
    try fetch.internal.populateRequestFromClient(request, client.request);
}

/// The global object of `realm`, or null for a realm that has none.
fn globalOfRealm(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    return @ptrCast(@alignCast(record.global_object orelse return null));
}
