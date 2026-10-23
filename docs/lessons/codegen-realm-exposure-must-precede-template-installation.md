# Codegen: Realm exposure must precede template installation

**Date**: 2026-10-21
**Lesson**: Record the target realm's exposure scope before installing interfaces, and install conditional non-configurable properties in that realm.

**Why**: An isolate can serve several kinds of realm. Its cached templates cannot encode one realm's member exposure for every later realm, and non-configurable properties cannot be removed after materialization.

**What Happened**: Worker templates were registered before the context recorded its worker scope. Interface-level exposure alone also missed member and partial-definition restrictions, such as XMLHttpRequest.responseXML and Performance members. A synthetic conditional constant and unforgeable member exposed the cases that prototype deletion cannot repair. The fresh-isolate checks then passed while a snapshot-isolate check still failed: V8 copies the default snapshot global's properties even when a new context uses a worker global template.

**Fix**: Keep WebIDL member overrides in generated metadata. Set ContextEntry's scope before interface and namespace installation. Filter configurable properties on each realm's interface objects, but defer conditional constants and unforgeables until the correct realm is available. Keep ordinary unforgeables on templates and compile the conditional wrapper work away when no interface requires it. In a snapshot isolate, remove copied interface objects and legacy Window names excluded from the destination scope. Test Window before and after worker/worklet creation, secure and insecure scopes, and snapshot restoration.

**Takeaway**: **A shared template describes the interface; realm-specific exposure belongs to installation in a known realm.**
