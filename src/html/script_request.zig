//! The request HTML's script fetches build: "create a potential-CORS
//! request", and Fetch's "populate request from client" for a script whose
//! settings object is a Window's.
//!
//! "fetch a classic script" (script_execution.zig) and "fetch a single module
//! script" (module_script.zig) both make their requests here, so both carry
//! what Fetch keys on: the destination (main fetch step 19's MIME type and
//! nosniff checks), the mode and credentials mode (CORS), and the client's
//! origin and referrer.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
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
/// settings object of `realm`'s Window - what Fetch reads from the client:
/// the traversable for user prompts, the origin, and the referrer. A realm
/// whose global is not a Window leaves them "client".
///
/// Spec: https://fetch.spec.whatwg.org/#populate-request-from-client
/// "If request's traversable for user prompts is "client": ... set request's
///  traversable for user prompts to global's navigable's traversable
///  navigable"; main fetch sets an origin of "client" to the client's
///  origin, and "determine request's referrer" makes a referrer of "client"
///  the document's URL - or no referrer for an opaque origin.
///
/// TODO: networking's fetch.internal.populateRequestFromClient, with
/// dom.global_settings.requestClient (which also carries the cookie jar), is
/// coming with the user-agent cookie jar; call it when it lands.
pub fn populateRequestFromClient(request: *InternalRequest, realm: runtime.Context) void {
    const window = windowOfRealm(realm) orelse return;
    request.traversable_for_user_prompts = .{ .traversable = window };
    const settings = global_settings.of(window) orelse return;
    const origin = settings.origin(window) catch return;
    defer window.ctx.allocator.free(origin);
    // An origin the Window does not know yet leaves the request's "client".
    if (origin.len == 0) return;
    request.setOrigin(origin) catch return;
    if (std.mem.eql(u8, origin, "null")) {
        request.setReferrer(.no_referrer);
    } else if (window.ctx.documentUrl()) |document_url| {
        request.setReferrerUrl(document_url) catch {};
    }
}

/// The Window whose realm `realm` is, or null for a realm whose global is not
/// a Window.
fn windowOfRealm(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (global.stateAs(interfaces.Window.State) == null) return null;
    return global;
}
