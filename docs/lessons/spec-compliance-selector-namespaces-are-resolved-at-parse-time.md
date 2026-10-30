# Spec Compliance: Resolve selector namespaces in their parsing context

**Date**: 2026-10-27
**Lesson**: A stylesheet binds selector prefixes to namespace URIs when parsing; DOM selector entry points have no stylesheet namespace environment.

**Why**: A prefix is a local alias, not part of an element's expanded name. Matching it later against an element's prefix is wrong. A default namespace also applies to implicit universal selectors, with the narrower subject exception inside `:is()`, `:where()` and `:not()`.

**What Happened**: The selector parser supported wildcard and empty namespaces but rejected every declared prefix. The sheet compiler approximated one default namespace with an `html_only` flag. That could not represent an arbitrary URI or distinguish an unqualified logical subject from an explicit `*` or an ancestor compound.

**Fix**: Pass the stylesheet's namespace environment into parsing, resolve a prefix once, and copy its URI into the AST's existing owned storage. Keep the old wildcard and empty-namespace representation unchanged. Use the same environment for stylesheet `@supports selector()` and real conditional `if()` support queries. CSS.supports and DOM query APIs retain a null resolver. Pin explicit and implicit universals, attribute namespaces, logical subjects, specificity, ownership and every allocation failure.

**Takeaway**: **Bind a namespace in the parser's environment and match its URI; do not infer that environment from the element being matched.**
