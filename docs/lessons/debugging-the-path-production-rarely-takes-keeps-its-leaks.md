# Debugging: The no-snapshot realm path leaked ~5,000 handles a realm, hidden behind the snapshot

**Date**: 2026-09-26
**Lesson**: Every realm made without the snapshot (JavaScriptCore's only path; WebDriver sessions; any browser whose snapshot is missing) stayed alive for the rest of the process: setupConstructorInheritance kept a key string, a constructor and a prototype per interface with a parent, registerLegacyInterfaceAliases its constructors, and the Intl registration every constructor, template and toLocaleString function it made - about 5,000 Global handles a realm (1,147,552 -> 1,626,304 bytes over 3 realms). The browser's usual path restores the snapshot and never runs this code, so nothing measured it.

**Fix**: release every handle those functions take (defer at the point of acquisition); pinned by "the interfaces defined on a realm without the snapshot keep none of its handles" and "a Window realm made and ended leaves no global handle behind" (global-handle bytes and native contexts flat).

**Takeaway**: **A path production rarely takes keeps every leak it has; measure the no-snapshot path's handles as well as the snapshot's.**
