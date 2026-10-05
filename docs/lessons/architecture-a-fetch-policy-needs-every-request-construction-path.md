# Architecture: A Fetch policy needs every request construction path

**Date**: 2026-10-05
**Lesson**: A policy checked in main fetch still needs its client state captured by every request producer, including navigation and WebSocket handshakes.

**Why**: Fetch operates on a request snapshot. It cannot reconstruct the initiating environment from the current document, and some platform operations build requests without the usual client-population helper.

**What Happened**: Adding Mixed Content checks to main fetch covered ordinary Fetch requests, but the navigation path built an InternalRequest directly and WebSockets connected through their own pump. Neither path carried the client's Mixed Content restriction. The baseline Crane tests observed HTTP traffic from an HTTPS initiator in both cases. An opaque data: frame also needs its authenticated ancestor's origin; the global's isSecureContext boolean answers a different question. The first WebSocket blocking check also exposed a missing UIR phase: the transport still connected to the constructor's original URL, so checking an HTTP(S) projection alone could never upgrade the actual connection.

**Fix**: Capture Mixed Content 4.3 by value when the request client or navigation source snapshot is made. Copy it through request cloning and retain it across redirects. Apply the shared UIR operation, Mixed Content upgrade, then policy blocking to WebSockets' mapped HTTP(S) handshake request. Connect to its final URL using a setter that can only run before transport starts; preserve the WebSocket object's constructor URL. Reuse the existing error/close path for blocked requests. Keep worker-owned integration as an explicit follow-up while its owner changes that path. Test the server stash so an unrelated client-side error cannot masquerade as blocking.

**Takeaway**: **Trace a policy from its owning settings object through every request constructor to the network boundary. A correct central predicate alone cannot enforce it.**
