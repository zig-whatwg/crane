# Spec Compliance: Blob URL lookup excludes fragments, but revocation does not

**Date**: 2026-10-17
**Lesson**: Resolve a Blob URL without its fragment, but revoke only an exact serialized URL key.

**Why**: File API §8.3 excludes the fragment when resolving an entry. Removing an entry in §8.2 serializes without that exclusion. Sharing one UUID-extraction operation cannot erase this difference.

**What Happened**: Fetch and XHR rejected valid Blob URLs containing fragments. The store extracted everything after the last slash, so fragment contents could also be mistaken for a live UUID. Matching only that suffix accepted a changed URL origin or extra path even though neither was the generated entry's key.

**Fix**: Remove the fragment only in resolution, before examining slashes. Keep revocation exact. Preserve the existing UUID index while comparing the remaining URL prefix against the entry's stored origin. No new entry state or ownership is needed. Native and Crane tests cover empty fragments, slashes and query characters inside fragments, query/path rejection, altered prefixes, and revocation that leaves the original URL live.

Chromium's `BlobUrlRegistry::GetBlobFromUrl` similarly looks up the full URL after `BlobUrlUtils::ClearUrlFragment`; its removal uses the full URL key: https://github.com/chromium/chromium/blob/main/storage/browser/blob/blob_url_registry.cc .

**Takeaway**: **Normalize for the specific algorithm, then compare the entire key; a matching UUID suffix is insufficient.**
