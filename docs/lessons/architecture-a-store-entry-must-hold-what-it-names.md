# Architecture: A store entry must hold what it names

**Date**: 2026-10-01
**Lesson**: The blob URL store kept a bare pointer to the Blob's data, which the Blob freed when the collector freed the Blob - while the URL, which script keeps instead of the Blob, could still be fetched.

**Why**: File API: a blob URL entry's object IS the Blob, held by the entry for as long as the entry is in the store. `URL.createObjectURL(new Blob([...]))` is the common shape: the Blob is garbage the moment the call returns, and the URL lives on. The store's comment said "We don't deinit the blob here as it may be referenced elsewhere" - true, and the reason it had to hold a reference of its own, not the reason it could skip one.

**What Happened**: `html/semantics/scripting-1/the-script-element/module/dynamic-import/blob-url.any.js` passed alone and segfaulted in `fetch_body.resolveBlobURL` (`Allocator.dupe` of the freed data's type) after aaj shard1's 61-file prefix, 6 of 6 runs of main-78e2b63ca's runner. It took two things the prefix supplied: an earlier file's `fetch()`, which installed the blob resolver scheme fetch asks (alone, no resolver was installed, so every `import()` of a blob URL was a network error before it could read anything - see the threadlocal-hook lesson), and a collection between `createObjectURL` and the worker's `import()`. A Crane test (`crane/c3-blob-url-outlives-blob.any.js`: drop the Blob, `TestUtils.gc()` twice, fetch and import the URL) read the poisoned bytes back as U+FFFD on main, every run. The store's unit test (drop the Blob's reference, resolve the URL) frees through an allocator that poisons what it frees, so the dangling read fails the same way in every build mode.

**Fix**: `BlobData` is reference-counted; `deinit` drops one reference. The Blob holds the one `init` makes, each store entry retains one in `createObjectURL` and releases it when revoked or when the store goes (Blink's BlobDataHandle, WebKit's `RefPtr<BlobData>` in its blob registry and Gecko's BlobImpl in BlobURLProtocolHandler are the same shape). Prefix 6/6 -> 0/6.

**Takeaway**: **A registry whose entries outlive the object they name must hold a reference of its own; "it may be referenced elsewhere" is the reason to take one.** To pin a dangling read in a unit test, free through an allocator that poisons what it frees.
