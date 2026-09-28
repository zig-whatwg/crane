# Spec Compliance: A referrer is a record, not a resource name

**Date**: 2026-09-27
**Lesson**: import() resolves against the referencing script's base URL. That URL belongs to the script's [[HostDefined]] record, and the string V8 compiled the script with is not a substitute for it.

**Why**: HostLoadImportedModule step 6 takes referencingScript from the Script or Module Record's [[HostDefined]] and resolves against its base URL. For an inline classic script, that is the document base URL when the script was prepared (prepare step 34.1). A script's resource name is only its filename for error reports: the script's URL, or the document's URL for an inline script.

**What Happened**: The legacy import() handler used V8's resource name as the referrer. For inline scripts that was the document URL, so eval() and Function() in an inline script ignored `<base>` (string-compilation-base-url-inline-classic 2/5). When navigation installed the protocol's hooks without the classic scripts carrying a record, import() in code that an external classic script compiled lost its referrer entirely: code-cache-base-url 5/6 -> 0/6, string-compilation-base-url-external-classic 4/5 -> 2/5, v8-code-cache 10/10 -> 5/10. The change was reverted (595b364b5).

**Fix**: R31 (7423457f9) runs every classic script through engine.runClassicScript with a `module_script.ClassicScript` as host_defined. The record is kept per document and base URL in the document's module map, and it is validated against the live records before it is read. With it, the hooks re-landed: those three files held at 5/6, 4/5 and 10/10, and inline-classic went from 2/5 to 4/5.

**Takeaway**: **Carry the spec's record across the engine boundary. Reconstructing a referrer from the string the engine happens to hold works only until the string and the record disagree, and for inline scripts they always did.**
