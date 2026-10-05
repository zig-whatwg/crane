//! The single lookup for a realm's decoder backend.
//! Host wiring is deferred to BrowserScope (media lane Q4); a host will replace
//! this lookup, not install a process-global mutable decoder or alter fetch.
const runtime = @import("runtime");
const media = @import("media_backend.zig");

pub fn forRealm(_: runtime.Context) media.MediaBackend {
    return media.no_decoder;
}
