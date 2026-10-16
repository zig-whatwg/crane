# Testing: A service worker variant is https whatever the file's name says

**Date**: 2026-10-16
**Lesson**: WPT's manifest loads every `.any.serviceworker.html` URL over TLS: a URL whose flags include "serviceworker" is https (`tools/manifest/item.py`, `URLManifestItem.https`). A runner that picks the scheme from the file name alone loads an http `.any.js` file's service worker variant over http, where `navigator.serviceWorker.register()` rejects - every such variant ERRORs.

**Why**: The `.https.` marker in a file name is one of two sources of the https flag; the variant suffix is the other. Crane's runner (`WptServer.buildTestUrl`) only read the first.

**What Happened**: Turning the runner's service worker variants on (lane sw1-b2), a sample of 87 worklist files went 25 blocking -> 69: 57 variants ended ERROR, "Unhandled rejection: The script URL's origin is not potentially trustworthy". With the variant's URL forced to the TLS listener, the same sample went 14 -> 9 blocking, +1,517 passing subtests, nothing newly blocking.

**Fix**: `buildTestUrl` puts a `.serviceworker` / `.serviceworker_module` variant on the https listener (h2 stays h2), and the server's test pins the URL.

**Takeaway**: **A runner's URL for a variant must follow every rule the manifest applies to it, not only the file name's markers - measure a sample before and after turning a variant on, and read the failure messages, not just the counts.**
