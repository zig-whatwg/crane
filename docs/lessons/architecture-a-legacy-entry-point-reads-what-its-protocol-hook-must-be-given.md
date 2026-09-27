# Architecture: A legacy entry point reads what its protocol hook must be given

**Date**: 2026-09-27
**Lesson**: Before switching an engine callback to a protocol hook, list what the legacy path read from the engine that the hook's arguments do not carry.

**Why**: V8's HostImportModuleDynamically callback hands over the referrer's resource name - the calling script's URL, even for code an external classic script compiled with eval, Function or a string timer. The legacy import() shim used that name as the base URL. The protocol's HostLoadImportedModule names the referrer only by its host_defined value (ImportReferrer.script). A script compiled without one - every classic script script_execution still runs on V8 directly - arrives as `.realm`, and HTML then resolves against the document's base URL.

**What Happened**: Installing script_execution.module_hooks on the page's agent (9ad3de9fa) compiled and passed zig build test. The A/B then showed dynamic-import/code-cache-base-url falling from 5/6 to 0/6, string-compilation-base-url-external-classic from 4/5 to 2/5, and v8-code-cache from 10/10 to 5/10. Every failure was "Failed to fetch dynamically imported module": the specifier resolved against `../` instead of the script's directory.

**Fix**: The switch was reverted (595b364b5). It re-lands once classic scripts run through `engine.runClassicScript` with a ClassicScript as `host_defined` (recipe R31). Those three files are the check.

**Takeaway**: **The old path's inputs are the new path's preconditions - diff them before the switch, and name the files that will show it.**
