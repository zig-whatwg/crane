# Debugging: Read the Linked V8 Patch Version

**Date**: 2026-10-21
**Lesson**: A nearby V8 tag can disagree with the linked prebuilt even within one minor version.

**Why**: Embedding API and experimental feature behavior changes between patch releases. A source-reading example in documentation identifies a useful checkout command, not necessarily the exact binary contract.

**What Happened**: The WebAssembly JSPI investigation initially read tag 13.1.99, following the repository's source-reading example. That tag's `WebAssemblySuspendingImpl` accepted a wasm exported function. The native baseline instead threw `TypeError: Argument 0 must not be a WebAssembly function`. Crane links 13.1.203; that tag's `src/wasm/wasm-js.cc:2393–2397` explicitly rejects wasm exported and typed wasm functions. The initial control expected a later import-routing behavior that the linked constructor could never reach.

**Fix**: Treat the native result as evidence, inspect the exact linked tag, and correct the control. Preserve native rejection by leaving wasm exports unwrapped; hiding one behind an apply proxy would bypass V8's check. Cite 13.1.203 in the final design evidence, while retaining the earlier investigation and its correction in the decision log.

**Takeaway**: **Measure the linked binary, then read its exact source tag before designing around an internal behavior.**
