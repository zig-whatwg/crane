# Codegen: Empty Legacy SVG Initializers Skip Parent State

**Date**: 2026-10-21
**Lesson**: An empty legacy initializer can disable the generated parent construction chain.

**Why**: Generated construction honors an impl's legacy init/deinit pair. A stub that only calls runtime.Instance.init creates its slab and type state but bypasses Node and Element initialization.

**What Happened**: Selecting SVGCircleElement instead of generic Element looked like a factory-only correction. A native constructor test failed before the factory changed: 64 SVG impls still had empty legacy construction/destruction stubs. Four component-transfer leaf interfaces also lacked impl modules.

**Fix**: Audit each stub's actual statements, remove only the empty legacy pairs, and let the generated chain construct and destroy ancestors. Keep nontrivial legacy constructors and existing deinitOwn functions. Create missing inherited-only impl modules and merge their exports from generated impls_tmp/root.zig into the hand-maintained impl root. Test parent node and attribute state before selecting the real interfaces, then createElementNS, XML parsing, HTML foreign-content parsing, cloning, allocation failures and teardown.

**Takeaway**: **A correct type name is not proof of a correctly constructed object. Pin parent state before broadening a factory's interface map.**
