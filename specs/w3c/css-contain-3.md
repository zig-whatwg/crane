## 1. Privacy Considerations

Not applicable.

## 2. Security Considerations

Not applicable.

## [Appendix A. Changes]
This appendix is *informative*.

### [ Changes since the 18 August 2022 Working Draft]
Significant changes since the [18 August 2022 Working
Draft](https://www.w3.org/TR/2022/WD-css-contain-3-20220818/) include:

- Move the definition of inline-size containement from this Level 3
 specification to Level 2. ([Issue
 10433](https://github.com/w3c/csswg-drafts/issues/10433))

- Move Container Queries to
 [\[CSS-CONDITIONAL-5\]](#biblio-css-conditional-5 "CSS Conditional Rules Module Level 5")
 ([Issue 10433](https://github.com/w3c/csswg-drafts/issues/10433))

Prior to the move, the following significant changes had been made, and
are reflected in
[\[CSS-CONDITIONAL-5\]](#biblio-css-conditional-5 "CSS Conditional Rules Module Level 5"):

- List all values of
 [contain](https://drafts.csswg.org/css-contain-2/#propdef-contain) in order to clarify serialization
 order ([Issue 8600](https://github.com/w3c/csswg-drafts/issues/8600))

- Add the
 [`containerName`](https://drafts.csswg.org/css-conditional-5/#dom-csscontainerrule-containername) and
 [`containerQuery`](https://drafts.csswg.org/css-conditional-5/#dom-csscontainerrule-containerquery) attributes. ([Issue
 7033](https://github.com/w3c/csswg-drafts/issues/7033))

- Correct typo in
 [container-type](https://drafts.csswg.org/css-conditional-5/#propdef-container-type) syntax, to clarify that
 [normal](https://drafts.csswg.org/css-conditional-5/#valdef-container-type-normal) cannot be combined with other values. ([Issue
 7669](https://github.com/w3c/csswg-drafts/issues/7669))

- Allow
 [var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) references in [container size
 queries](https://drafts.csswg.org/css-conditional-5/#container-size-query). ([Issue
 8088](https://github.com/w3c/csswg-drafts/issues/8088))

- Allow comma-separated
 [\<container-condition\>](https://drafts.csswg.org/css-conditional-5/#typedef-container-condition)s to match different containers.
 ([Issue 7551](https://github.com/w3c/csswg-drafts/issues/7551))

### [ Changes since the 21 December 2021 First Public Working Draft]
Significant changes since the [21 December 2021 First Public Working
Draft](https://www.w3.org/TR/2021/WD-css-contain-3-20211221/) include:

- Allow the computed value of
 [container-name](https://drafts.csswg.org/css-conditional-5/#propdef-container-name) to include duplicate identifiers.
 ([Issue 7181](https://github.com/w3c/csswg-drafts/issues/7181))

- Make the
 [\<\'container-name\'\>](https://drafts.csswg.org/css-conditional-5/#propdef-container-name) in the
 [container](https://drafts.csswg.org/css-conditional-5/#propdef-container) shorthand required. ([Issue
 7142](https://github.com/w3c/csswg-drafts/issues/7142))

- Clarify handling of [shorthand
 properties](https://drafts.csswg.org/css-cascade-5/#shorthand-property) in [container style
 queries](https://drafts.csswg.org/css-conditional-5/#container-style-query). ([Issue
 7095](https://github.com/w3c/csswg-drafts/issues/7095))

- [Cascade-dependent
 keywords](https://drafts.csswg.org/css-cascade-5/#cascade-dependent-keyword) are not allowed as values in a [style
 feature](https://drafts.csswg.org/css-conditional-5/#style-features), and cause the [container style
 query](https://drafts.csswg.org/css-conditional-5/#container-style-query) to be false. ([Issue
 7080](https://github.com/w3c/csswg-drafts/issues/7080))

- Change the initial value of
 [container-type](https://drafts.csswg.org/css-conditional-5/#propdef-container-type) to be
 [normal](https://drafts.csswg.org/css-conditional-5/#valdef-container-type-normal), which establishes elements as containers for
 [style
 features](https://drafts.csswg.org/css-conditional-5/#style-features). ([Issue
 6393](https://github.com/w3c/csswg-drafts/issues/6393), [Issue
 7066](https://github.com/w3c/csswg-drafts/issues/7066), [Issue
 7402](https://github.com/w3c/csswg-drafts/issues/7402))

- Remove the block-size value from
 [container-type](https://drafts.csswg.org/css-conditional-5/#propdef-container-type), since single-axis block-size
 containment is not currently possible. ([Issue
 1031](https://github.com/w3c/csswg-drafts/issues/1031))

- Remove the
 [\<string\>](https://drafts.csswg.org/css-values-4/#string-value) option from the
 [container-name](https://drafts.csswg.org/css-conditional-5/#propdef-container-name) syntax. Container names must be
 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value)s. ([Issue
 6405](https://github.com/w3c/csswg-drafts/issues/6405))

- Reverse the order of
 [\<\'container-name\'\>](https://drafts.csswg.org/css-conditional-5/#propdef-container-name) and
 [\<\'container-type\'\>](https://drafts.csswg.org/css-conditional-5/#propdef-container-type) in the
 [container](https://drafts.csswg.org/css-conditional-5/#propdef-container) shorthand property, with both
 being optional. ([Issue
 6393](https://github.com/w3c/csswg-drafts/issues/6393))

- Allow
 [\<general-enclosed\>](https://drafts.csswg.org/mediaqueries-5/#typedef-general-enclosed) syntax in
 [\<container-condition\>](https://drafts.csswg.org/css-conditional-5/#typedef-container-condition)s, for the sake of forward
 compatibility. ([Issue
 6396](https://github.com/w3c/csswg-drafts/issues/6396))

- Remove the size function syntax from
 [\<size-feature\>](https://drafts.csswg.org/css-conditional-5/#typedef-size-feature) queries. ([Issue
 6870](https://github.com/w3c/csswg-drafts/issues/6870))

- Update the [query
 container](https://drafts.csswg.org/css-conditional-5/#query-container) selection process to account for necessary
 container-types, and removed the explicit type-selection syntax.
 ([Issue 6644](https://github.com/w3c/csswg-drafts/issues/6644))

- Remove state query features, which have been deferred. ([Issue
 6402](https://github.com/w3c/csswg-drafts/issues/6402))

- Clarify container selection around pseudo-elements and the shadow-DOM.
 ([Issue 5984](https://github.com/w3c/csswg-drafts/issues/5984) and
 [Issue 6711](https://github.com/w3c/csswg-drafts/issues/6711))

### [ Changes from [CSS Containment Level 2](https://www.w3.org/TR/css-contain-2/) ]
- Introduces [inline-size
 containment](https://drafts.csswg.org/css-contain-2/#inline-size-containment).

- Defines the terms, properties, units, and at-rule needed for
 [Container
 Queries](https://drafts.csswg.org/css-conditional-5/#container-query)
