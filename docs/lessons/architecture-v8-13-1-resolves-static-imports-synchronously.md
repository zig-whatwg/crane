# Architecture: V8 13.1 resolves static imports synchronously

**Date**: 2026-09-22
**Lesson**: There is no HostLoadImportedModule for static imports in V8 13.1:
imports resolve during `InstantiateModule`, so the loader
(`src/html/module_script.zig`, 0a3e4fac4) walks and fetches the whole graph
first, then links - d8's design. With synchronous fetches a depth-first walk
reports the same first error as the spec's concurrent one. Record each
module's edges while loading; the resolve callback sees only the importer's
identity hash.
