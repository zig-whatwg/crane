## 1. Introduction

The features in level 3 are still
defined in
[\[css-conditional-3\]](#biblio-css-conditional-3 "CSS Conditional Rules Module Level 3")
and have not yet been copied here.

This level adds extensions to the
[\@supports](https://drafts.csswg.org/css-conditional-3/#at-ruledef-supports) rule to allow testing for supported selectors.

## [2. ][ Extensions to the [\@supports](https://drafts.csswg.org/css-conditional-3/#at-ruledef-supports) rule]
This level of the specification extends the
[\<supports-feature\>](#typedef-supports-feature) syntax as follows:

```
<supports-feature> = <supports-selector-fn> | <supports-decl>
<supports-selector-fn> = selector( <complex-selector> )
```

[\<supports-selector-fn\>](#typedef-supports-selector-fn)

: The result is true if the UA [supports the
 selector](#dfn-support-selector)
 provided as an argument to the function.

Tests

- [at-supports-selector-001.html](https://wpt.fyi/results/css/css-conditional/at-supports-selector-001.html "css/css-conditional/at-supports-selector-001.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-selector-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-selector-001.html)
- [at-supports-selector-002.html](https://wpt.fyi/results/css/css-conditional/at-supports-selector-002.html "css/css-conditional/at-supports-selector-002.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-selector-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-selector-002.html)
- [at-supports-selector-003.html](https://wpt.fyi/results/css/css-conditional/at-supports-selector-003.html "css/css-conditional/at-supports-selector-003.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-selector-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-selector-003.html)
- [at-supports-selector-004.html](https://wpt.fyi/results/css/css-conditional/at-supports-selector-004.html "css/css-conditional/at-supports-selector-004.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-selector-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-selector-004.html)
- [at-supports-selector-details-content-before.html](https://wpt.fyi/results/css/css-conditional/at-supports-selector-details-content-before.html "css/css-conditional/at-supports-selector-details-content-before.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-selector-details-content-before.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-selector-details-content-before.html)
- [at-supports-selector-details-content.html](https://wpt.fyi/results/css/css-conditional/at-supports-selector-details-content.html "css/css-conditional/at-supports-selector-details-content.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-selector-details-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-selector-details-content.html)
- [at-supports-selector-detecting-invalid-in-logical-combinations.html](https://wpt.fyi/results/css/css-conditional/at-supports-selector-detecting-invalid-in-logical-combinations.html "css/css-conditional/at-supports-selector-detecting-invalid-in-logical-combinations.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-selector-detecting-invalid-in-logical-combinations.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-selector-detecting-invalid-in-logical-combinations.html)
- [at-supports-selector-file-selector-button.html](https://wpt.fyi/results/css/css-conditional/at-supports-selector-file-selector-button.html "css/css-conditional/at-supports-selector-file-selector-button.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-selector-file-selector-button.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-selector-file-selector-button.html)
- [at-supports-selector-placeholder.html](https://wpt.fyi/results/css/css-conditional/at-supports-selector-placeholder.html "css/css-conditional/at-supports-selector-placeholder.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-selector-placeholder.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-selector-placeholder.html)
- [CSS-supports-L4.html](https://wpt.fyi/results/css/css-conditional/js/CSS-supports-L4.html "css/css-conditional/js/CSS-supports-L4.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/js/CSS-supports-L4.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/js/CSS-supports-L4.html)
- [CSS-supports-selector-detecting-invalid-in-logical-combinations.html](https://wpt.fyi/results/css/css-conditional/js/CSS-supports-selector-detecting-invalid-in-logical-combinations.html "css/css-conditional/js/CSS-supports-selector-detecting-invalid-in-logical-combinations.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/js/CSS-supports-selector-detecting-invalid-in-logical-combinations.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/js/CSS-supports-selector-detecting-invalid-in-logical-combinations.html)
- [CSS-supports-details-content-pseudo-parsing.html](https://wpt.fyi/results/css/css-conditional/js/CSS-supports-details-content-pseudo-parsing.html "css/css-conditional/js/CSS-supports-details-content-pseudo-parsing.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/js/CSS-supports-details-content-pseudo-parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/js/CSS-supports-details-content-pseudo-parsing.html)

This example tests whether the [column
combinator](https://drafts.csswg.org/selectors-5/#column-combinator) (\|\|) is supported in selectors, and if so uses it to
style particular cells in a table.

```
@supports selector(col || td) {
 col.selected || td {
 background: tan;
 }
}
```

Any namespace prefixes used in a [conditional group
rule](https://drafts.csswg.org/css-conditional-3/#conditional-group-rule) must have been declared, otherwise they are invalid
[\[css-conditional-3\]](#biblio-css-conditional-3 "CSS Conditional Rules Module Level 3").
This includes namespace prefixes inside the selector function.

Tests

- [at-supports-namespace-002.html](https://wpt.fyi/results/css/css-conditional/at-supports-namespace-002.html "css/css-conditional/at-supports-namespace-002.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-namespace-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-namespace-002.html)

This example tries to check that
attribute selectors with [CSS qualified
names](https://drafts.csswg.org/css-namespaces-3/#css-qualified-name) are supported, but is invalid, because the namespace
prefix has not been declared.

```
@supports selector(a[xlink|href]) {
 // do something, but fail
}
```

This example checks that attribute
selectors with [CSS qualified
names](https://drafts.csswg.org/css-namespaces-3/#css-qualified-name) are supported.

```
@namespace x url(http://www.w3.org/1999/xlink);
@supports selector(a[x|href]) {
 // do something
}
```

### 2.1. Extensions to the definition of support

A CSS processor is considered to [support a CSS
selector] if it accepts that all aspects of that
selector, recursively, (rather than considering any of its syntax to be
unknown or invalid) and that selector doesn't contain [unknown -webkit-
pseudo-elements](https://drafts.csswg.org/selectors-4/#unknown--webkit--pseudo-elements).

 Some functional selectors are parsed forgivingly, i.e.
if some arguments are unknown/invalid, the selector itself is not
invalidated. These are nonetheless unsupported

## [Security Considerations]
No Security issues have been raised against this document

## [Privacy Considerations]
The [selector()] function may provide information about the user's
software such as its version and whether it is running with non-default
settings that enable or disable certain features.

This information can also be determined through other APIs. However, the
features in this specification are one of the ways this information is
exposed on the Web.

This information can also, in aggregate, be used to improve the accuracy
of
[fingerprinting](https://www.w3.org/2001/tag/doc/unsanctioned-tracking/)
of the user.

## [Acknowledgments]
The editors would like to thank all of the contributors to the [previous
level](https://www.w3.org/TR/css-conditional-3/#acknowledgments) of this
module.

## [ Changes]
### [ Changes since the [Candidate Recommendation Draft of 4 September 2025](https://www.w3.org/TR/2025/CRD-css-conditional-4-20250904/)]
- *none*

### [ Changes since the [Candidate Recommendation Snapshot of 17 February 2022](https://www.w3.org/TR/2022/CR-css-conditional-4-20220217/)]
- Clarify that unknown or invalid portions of a selector that do not
 invalidate the selector nonetheless cause the selector to be
 considered unsupported.

### [ Changes since the [First Public Working Draft of 3 March 2020](https://www.w3.org/TR/2020/WD-css-conditional-4-20200303/)]
- Added [Privacy](#privacy) and [Security](#security) sections.
- Added some examples
- Clarified that the requirement to declare namespace prefixes applies
 to selectors inside selector() ([Issue
 3220](https://github.com/w3c/csswg-drafts/issues/3220))

### [ Additions since Level 3]
- Added [selector()] notation to [supports
 queries](https://drafts.csswg.org/css-conditional-3/#supports-queries).
