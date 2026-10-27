## 1. Introduction and Missing Sections

This is a diff spec over [CSS Cascading
and Inheritance Level 5](https://www.w3.org/TR/css-cascade-5/). It is
currently an Exploratory Working Draft: if you are implementing
anything, please use Level 5 as a reference. We will merge the Level 5
text into this draft once it reaches CR.

## 2. Importing Style Sheets: the [\@import rule]
The [\@import] rule allows users to import style rules
from other style sheets. If an
[\@import](#at-ruledef-import) rule refers to a valid stylesheet, user agents must
treat the contents of the stylesheet as if they were written in place of
the [\@import] rule, with two
exceptions:

- If a feature (such as the
 [\@namespace](https://drafts.csswg.org/css-namespaces-3/#at-ruledef-namespace) rule) *explicitly* defines that it only
 applies to a particular stylesheet, and not any imported ones, then it
 doesn't apply to the imported stylesheet.

- If a feature relies on the relative ordering of two or more constructs
 in a stylesheet (such as the requirement that
 [\@namespace](https://drafts.csswg.org/css-namespaces-3/#at-ruledef-namespace) rules must not have any other rules other than
 [\@import](#at-ruledef-import) preceding it), it only applies between constructs
 in the same stylesheet.

For example,
[declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) in style rules from imported stylesheets interact with
the cascade as if they were written literally into the stylesheet at the
point of the [\@import](#at-ruledef-import).

Any [\@import](#at-ruledef-import) rules must precede all other valid at-rules and style
rules in a style sheet (ignoring
[\@charset](https://drafts.csswg.org/css-syntax-3/#at-ruledef-charset),
[\@supports-condition](https://drafts.csswg.org/css-conditional-5/#at-ruledef-supports-condition), and [[\@layer] statement](#layer-empty)
rules) and must not have any other valid at-rules or style rules between
it and previous [\@import] rules, or
else the [\@import] rule is invalid.
The syntax of [\@import] is:

``` prod
@import [ <url> | <string> ]
 [[ layer | layer( <layer-name> ) ]
 || [ scope | scope( <scope-start> | <scope-boundaries> ) ]
 || <supports-import-condition>]?
 <media-import-condition> ;

<supports-import-condition> = supports( [ <supports-condition> | <declaration> ] )
<media-import-condition> = <media-query-list>
```

where:

- the
 [\<url\>](https://drafts.csswg.org/css-values-4/#url-value) or
 [\<string\>](https://drafts.csswg.org/css-values-4/#string-value) gives the URL of the style sheet to
 be imported.

and optionally:

- the [layer] keyword or [layer()] function, which assigns
 the contents of the style sheet into its own anonymous [cascade
 layer](https://drafts.csswg.org/css-cascade-5/#cascade-layers) or into the named [cascade
 layer].

 The layer is added to the [layer order](#layer-ordering) even if the
 import fails to load the stylesheet, but is subject to any [import
 conditions](#import-conditions) (just as if declared by an
 [\@layer](https://drafts.csswg.org/css-cascade-5/#at-ruledef-layer) rule wrapped in the appropriate [conditional
 group
 rules](https://drafts.csswg.org/css-conditional-3/#conditional-group-rule)).

- the [scope] keyword or [scope()] function, which
 [scopes](#scope) the [style
 rules](https://drafts.csswg.org/css-syntax-3/#style-rule) within the stylesheet, using the [scoping
 roots](https://drafts.csswg.org/selectors-4/#scoping-root) and [scoping
 limits](#scoping-limit) as
 described by [§ 3.5.4 Identifying Scoping Roots and
 Limits](#scope-limits).

 The [scope] keyword behaves like a
 [\@scope](#at-ruledef-scope) rule with an empty prelude, scoping the imported
 rules to the [parent
 element](https://dom.spec.whatwg.org/#parent-element) of the [owner
 node](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-owner-node) of the stylesheet containing the
 [\@import](#at-ruledef-import) rule.

 While the [style
 rules](https://drafts.csswg.org/css-syntax-3/#style-rule) within the imported stylesheet become
 [scoped](#scope), they do not become
 [nested](https://drafts.csswg.org/css-nesting-1/#nested-style-rule). In particular, top-level selectors are not
 re-interpreted as [relative
 selectors](https://drafts.csswg.org/selectors-4/#relative-selector), and the
 [&](https://drafts.csswg.org/css-nesting-1/#selectordef-) pseudo-class maintains its non-nested
 behavior.

- the [import
 conditions](#import-conditions),
 [\<supports-import-condition\>](#typedef-supports-import-condition) and
 [\<media-import-condition\>](#typedef-media-import-condition), which state the conditions under
 which the [\@import](#at-ruledef-import) rule applies.

The following [conditional
[\@import] rule](#conditional-import) only loads the style sheet
when the UA
[supports](https://www.w3.org/TR/css-conditional-3/#support-definition)
[display:
flex](https://drafts.csswg.org/css-display-4/#propdef-display), and only applies the style sheet on a
[handheld](https://www.w3.org/TR/CSS2/media.html#media-types) device
with a [maximum viewport
width](https://www.w3.org/TR/mediaqueries-4/#width) of 400px.

 @import url("narrow.css") supports(display: flex) handheld and (max-width: 400px);

The following layer imports load the
style sheets into the [framework.component] layer, and an un-named
layer, respectively:

 @import url("tabs.css") layer(framework.component);
 @import url("override.css") layer;

The following imports a stylesheet,
and scopes the style rules to elements matching `.card`.

 @import url("card.css") scope(.card);

If a
[\<string\>](https://drafts.csswg.org/css-values-4/#string-value) is provided, it must be interpreted
as a
[\<url\>](https://drafts.csswg.org/css-values-4/#url-value) with the same value.

The following lines are equivalent in
meaning and illustrate both
[\@import](#at-ruledef-import) syntaxes (one with
[url()](https://drafts.csswg.org/css-values-3/#funcdef-url) and one with a bare string):

```
@import "mystyle.css";
@import url("mystyle.css");
```

### 2.1. Conditional [\@import Rules]
[Import conditions] allow the import to be media-- or feature-support--dependent.
In the absence of any [import
conditions](#import-conditions), the import is unconditional. (Specifying [all]
for the
[\<media-query-list\>](https://drafts.csswg.org/mediaqueries-4/#typedef-media-query-list) has the same effect.) If the [import
conditions] do not match, the rules in the
imported stylesheet do not apply, exactly as if the imported stylesheet
were wrapped in
[\@media](https://drafts.csswg.org/css-conditional-3/#at-ruledef-media) and/or
[\@supports](https://drafts.csswg.org/css-conditional-3/#at-ruledef-supports) blocks with the given conditions.

The following rules illustrate how
[\@import](#at-ruledef-import) rules can be made media-dependent:

```
@import url("fineprint.css") print;
@import url("bluish.css") projection, tv;
@import url("narrow.css") handheld and (max-width: 400px);
```

User agents may therefore avoid fetching a conditional import as long as
the [import conditions](#import-conditions) do not match. Additionally, if a
[\<supports-condition\>](https://drafts.csswg.org/css-conditional-3/#typedef-supports-condition) blocks the application of the
imported style sheet, the UA *must not* fetch the style sheet (unless it
is loaded through some other link) and *must* return null for the import
rule's CSSImportRule.styleSheet value (even if it is loaded through some
other link).

The following rule illustrates how an
author can provide fallback rules for legacy user agents without
impacting network performance on newer user agents:

```
@import url("fallback-layout.css") supports(not (display: flex));
@supports (display: flex) {
 ...
}
```

The [import conditions](#import-conditions) are given by
[\<media-query-list\>](https://drafts.csswg.org/mediaqueries-4/#typedef-media-query-list), which is parsed and interpreted as a
[media query
list](https://drafts.csswg.org/mediaqueries-4/#media-query-list), and
[\<supports-condition\>](https://drafts.csswg.org/css-conditional-3/#typedef-supports-condition), is parsed and interpreted as a
[supports
query](https://drafts.csswg.org/css-conditional-3/#supports-queries). If a
[\<declaration\>](https://drafts.csswg.org/css-conditional-5/#typedef-declaration) is given in place of a
[\<supports-condition\>], it must be interpreted as a
[\<supports-decl\>](https://drafts.csswg.org/css-conditional-5/#typedef-supports-decl) (i.e. the extra set of parentheses is
implied) and treated as a
[\<supports-condition\>].

For example, the following two lines
are equivalent:

```
@import "mystyle.css" supports(display: flex);
@import "mystyle.css" supports((display: flex));
```

The evaluation and full syntax of the [import
conditions](#import-conditions) are defined by the [Media
Queries](https://www.w3.org/TR/mediaqueries/)
[\[MEDIAQ\]](#biblio-mediaq "Media Queries Level 4")
and [CSS Conditional Rules](https://www.w3.org/TR/css-conditional/)
[\[CSS-CONDITIONAL-3\]](#biblio-css-conditional-3 "CSS Conditional Rules Module Level 3")
specifications.

### 2.2. Processing Stylesheet Imports

When the same style sheet is imported or linked to a document in
multiple places, user agents must process (or act as though they do)
each link as though the link were to an independent style sheet.

 This does not place any requirements on resource
fetching, only how the style sheet is reflected in the CSSOM and used in
specs such as this one. Assuming appropriate caching, it is perfectly
appropriate for a UA to fetch a style sheet only once, even though it's
linked or imported multiple times.

The [cascade origin](#origin) of an
imported style sheet is the [cascade origin] of the
style sheet that imported it.

The [environment
encoding](https://drafts.csswg.org/css-syntax-3/#environment-encoding) of an imported style sheet is the encoding of the style
sheet that imported it.
[\[css-syntax-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3")

### 2.3. Content-Type of CSS Style Sheets

The processing of imported style sheets depends on the actual type of
the linked resource:

- If the resource does not have [Content-Type
 metadata](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#content-type), the type is treated as `text/css`.

- If the host document is in [quirks
 mode](https://dom.spec.whatwg.org/#concept-document-quirks), and the host document's origin is [same
 origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin) with the linked resource
 [response's](https://fetch.spec.whatwg.org/#concept-response)
 [URL's](https://fetch.spec.whatwg.org/#concept-response-url) origin, the type is treated as `text/css`.

- Otherwise, the type is determined from its [Content-Type
 metadata](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#content-type).

If the linked resource's type is `text/css`, it must be interpreted as a
CSS style sheet. Otherwise, it must be interpreted as a network error.

## 3. Cascading

The [cascade] takes
an unordered list of [declared
values](https://drafts.csswg.org/css-cascade-5/#declared-value) for a given property on a given element, sorts them by
their
[declaration's](https://drafts.csswg.org/css-syntax-3/#declaration) precedence as determined below, and outputs a single
[cascaded
value](https://drafts.csswg.org/css-cascade-5/#cascaded-value).

### 3.1. Cascade Sorting Order

The cascade sorts
[declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) according to the following criteria, in descending
order of precedence:

Origin and Importance

: The [origin](#origin) of a
 [declaration](https://drafts.csswg.org/css-syntax-3/#declaration) is based on where it comes from and its
 [importance](#important) is
 whether or not it is declared with [!important] (see
 [below](#importance)). The precedence of the various
 [origins] is, in descending order:

 1. Transition declarations
 [\[css-transitions-1\]](#biblio-css-transitions-1 "CSS Transitions Module Level 1")
 2. [Important](#important)
 [user
 agent](https://drafts.csswg.org/css-cascade-5/#cascade-origin-ua) declarations
 3. [Important](#important)
 [user](https://drafts.csswg.org/css-cascade-5/#cascade-origin-user) declarations
 4. [Important](#important)
 [author](https://drafts.csswg.org/css-cascade-5/#cascade-origin-author) declarations
 5. Animation declarations
 [\[css-animations-1\]](#biblio-css-animations-1 "CSS Animations Level 1")
 6. [Normal](#normal)
 [author](https://drafts.csswg.org/css-cascade-5/#cascade-origin-author) declarations
 7. [Normal](#normal)
 [user](https://drafts.csswg.org/css-cascade-5/#cascade-origin-user) declarations
 8. [Normal](#normal) [user
 agent](https://drafts.csswg.org/css-cascade-5/#cascade-origin-ua) declarations

 Declarations from [origins](#origin) earlier in this list win over declarations from
 later [origins].

Context

: A document language can provide for blending
 [declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) sourced from different [encapsulation
 contexts], such as the nested [tree
 contexts](https://drafts.csswg.org/css-shadow-1/#tree-context) of [shadow
 trees](https://dom.spec.whatwg.org/#concept-shadow-tree) in the
 [\[DOM\]](#biblio-dom "DOM Standard").

 When comparing two declarations that are sourced from different
 [encapsulation
 contexts](#encapsulation-contexts), then for [normal](#normal) rules the declaration from the outer context wins,
 and for [important](#important)
 rules the declaration from the inner context wins. For this purpose,
 [\[DOM\]](#biblio-dom "DOM Standard") [tree
 contexts](https://drafts.csswg.org/css-shadow-1/#tree-context) are considered to be nested in [shadow-including
 tree
 order](https://dom.spec.whatwg.org/#concept-shadow-including-tree-order).

 This effectively means that
 [normal](#normal) declarations
 belonging to an [encapsulation
 context](#encapsulation-contexts) can set defaults that are easily overridden by the
 outer context, while [important](#important) declarations belonging to an [encapsulation
 context] can enforce requirements
 that cannot be overridden by the outer context.

The Style Attribute
: Separately for [normal](#normal)
 and [important](#important)
 [declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations), declarations that are attached directly to an
 element (such as the [contents of a style
 attribute](https://www.w3.org/TR/css-style-attr/#interpret)) rather
 than indirectly mapped by means of a style rule selector take
 precedence over declarations the same
 [importance] that are mapped via style rule.

Layers

: [Declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) within each [origin](#origin) and
 [context](#encapsulation-contexts) can be explicitly assigned to a [cascade
 layer](https://drafts.csswg.org/css-cascade-5/#cascade-layers). For the purpose of this step, any declaration not
 assigned to an explicit layer is added to an implicit final layer.

 Cascade layers (like declarations) are sorted by order of
 appearance, see [§ 3.4.1 Layer Ordering](#layer-ordering). When
 comparing declarations that belong to different layers, then for
 [normal](#normal) rules the
 declaration whose [cascade
 layer](https://drafts.csswg.org/css-cascade-5/#cascade-layers) is latest in the layer order wins, and for
 [important](#important) rules
 the declaration whose [cascade layer] is
 earliest wins.

 This follows the same logic used for precedence of
 [normal](#normal) and
 [important](#important)
 [origins](#origin), thus the
 [!important] flag maintains the same "override" purpose in
 both settings.

Specificity

: The [Selectors module](https://www.w3.org/TR/selectors/#specificity)
 [\[SELECT\]](#biblio-select "Selectors Level 3")
 describes how to compute the specificity of a selector.

 When comparing declarations from two style rules, the declaration
 belonging to the style rule with the highest specificity wins.

[Scope Proximity]
: When comparing declarations that appear in style rules with
 different [scoping
 roots](https://drafts.csswg.org/selectors-4/#scoping-root), then the declaration with the fewest generational
 or sibling-element hops between the [scoping
 root] and the [scoped style
 rule](#scoped-style-rules)
 [subject](https://drafts.csswg.org/selectors-4/#selector-subject) wins. For this purpose, style rules without a
 [scoping root] are considered to have
 infinite proximity hops.

Order of Appearance
: The last declaration in document order wins. For this purpose:
 - Style sheets are ordered as in [final CSS style
 sheets](https://drafts.csswg.org/cssom/#documentorshadowroot-final-css-style-sheets).
 - Declarations from [imported style
 sheets](#at-ruledef-import) are ordered as if their style sheets were
 substituted in place of the
 [\@import] rule.
 - Declarations from style sheets independently linked by the
 originating document are treated as if they were concatenated in
 linking order, as determined by the host document language.
 - Declarations from style attributes are ordered according to the
 document order of the element the style attribute appears on, and
 are all placed after any style sheets.
 [\[CSSSTYLEATTR\]](#biblio-cssstyleattr "CSS Style Attributes")

The [output of the cascade] is a (potentially empty) sorted list of
[declared
values](https://drafts.csswg.org/css-cascade-5/#declared-value) for each property on each element.

### 3.2. Cascading Origins

[CSS Cascading 5 § 6.2 Cascading
Origins](https://drafts.csswg.org/css-cascade-5/#cascading-origins)

[cascade origin]

### [3.3. ][ Important Declarations: the [!important] annotation]
(#issue-d41d8cd9①) [CSS Cascading 5 § 6.3 Important
Declarations: the !important
annotation](https://drafts.csswg.org/css-cascade-5/#importance)

[important] [normal]

### 3.4. Cascade Layers

(#issue-d41d8cd9②) [CSS Cascading 5 § 6.4 Cascade
Layers](https://drafts.csswg.org/css-cascade-5/#layering)

#### 3.4.1. Layer Ordering

(#issue-d41d8cd9③) [CSS Cascading 5 § 6.4.3 Layer
Ordering](https://drafts.csswg.org/css-cascade-5/#layer-ordering)

### 3.5. Scoping Styles: the [\@scope rule]
A [scope] is a
subtree or fragment of a document, which can be used by selectors for
more targeted matching. A [scope](#scope) is formed by determining:

- The [scoping
 root](https://drafts.csswg.org/selectors-4/#scoping-root)
 [node](https://dom.spec.whatwg.org/#boundary-point-node), which acts as the upper bound of the scope, and
 optionally:

- The [scoping limit] elements, which act as the lower bounds.

An element is [in scope] if:

- It is an [inclusive
 descendant](https://dom.spec.whatwg.org/#concept-tree-inclusive-descendant) of the [scoping
 root](https://drafts.csswg.org/selectors-4/#scoping-root), and

- It is not an [inclusive
 descendant](https://dom.spec.whatwg.org/#concept-tree-inclusive-descendant) of a [scoping
 limit](#scoping-limit).

 In contrast to [Shadow
Encapsulation](https://drafts.csswg.org/css-scoping/#shadow-dom), which
describes a persistent one-to-one relationship in the DOM between a
[shadow host] and its nested [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree), multiple overlapping [scopes](#scope) can be defined in relation to the same elements.

Scoped styles are described in CSS using the [\@scope] [block
at-rule](https://drafts.csswg.org/css-syntax-3/#block-at-rule), which declares a [scoping
root](https://drafts.csswg.org/selectors-4/#scoping-root) and optional [scoping
limits](#scoping-limit)
associated with a set of [style
rules](https://drafts.csswg.org/css-syntax-3/#style-rule).

For example, an author might have
wide-reaching color-scheme scopes, which overlap more narrowly-scoped
design patterns such as a media object. The selectors in the
[\@scope](#at-ruledef-scope) rule establish [scoping
root](https://drafts.csswg.org/selectors-4/#scoping-root) and optional [scoping
limit](#scoping-limit)
elements, while the nested selectors only match elements that are [in a
resulting scope](#in-scope):

``` highlight
@scope (.light-scheme) {
 /* Only match links inside a light-scheme */
 a { color: darkmagenta; }
}

@scope (.dark-scheme) {
 /* Only match links inside a dark-scheme */
 a { color: plum; }
}

@scope (.media-object) {
 /* Only match author images inside a media-object */
 .author-image { border-radius: 50%; }
}
```

By providing [scoping
limits](#scoping-limit), an
author can limit matching more deeply nested descendants. For example:

``` highlight
@scope (.media-object) to (.content > *) {
 img { border-radius: 50%; }
 .content { padding: 1em; }
}
```

The [img] selector will only match image tags that are in a DOM
fragment starting with any [.media-object], and including all
descendants up to any intervening children of the [.content]
class.

Should scoping limits be added to the
definition of [scoped
selectors](https://drafts.csswg.org/selectors-4/#scoped-selector)?

#### 3.5.1. Effects of [\@scope]
The [\@scope](#at-ruledef-scope)
[at-rule](https://drafts.csswg.org/css-syntax-3/#at-rule) has three primary effects on the [style
rules](https://drafts.csswg.org/css-syntax-3/#style-rule) it contains:

- The [style
 rules](https://drafts.csswg.org/css-syntax-3/#style-rule) in an
 [\@scope](#at-ruledef-scope)
 [\<rule-list\>](https://drafts.csswg.org/css-syntax-3/#typedef-rule-list) are [scoped style
 rules](#scoped-style-rules).

- The
 [:scope](https://drafts.csswg.org/selectors-4/#scope-pseudo) selector is defined to match the
 [\@scope](#at-ruledef-scope) rule's [scoping
 root](https://drafts.csswg.org/selectors-4/#scoping-root), including the
 [featureless](https://drafts.csswg.org/selectors-4/#featureless) [shadow host] when that host is the
 [scoping root].

- The
 [&](https://drafts.csswg.org/css-nesting-1/#selectordef-) selector is defined to behave as
 `:where(:scope)`.

- The [cascade](#cascade) prioritizes
 declarations with a [more
 proximate](#scope-proximity)
 [scoping
 root](https://drafts.csswg.org/selectors-4/#scoping-root), regardless of specificity or order of appearance by
 applying [scope proximity] between the
 [scoping root] and the
 [subject](https://drafts.csswg.org/selectors-4/#selector-subject) of each [scoped style
 rule](#scoped-style-rules).

 Unlike [Nesting](https://www.w3.org/TR/css-nesting/),
selectors within an
[\@scope](#at-ruledef-scope) rule do not acquire the specificity of any parent
selector(s) in the [\@scope] prelude.

The following selectors have the same
specificity (0,0,1):

``` highlight
@scope (#hero) {
 img { border-radius: 50%; }
}

:where(#hero) img { border-radius: 50%; }
```

The additional specificity of the [#hero] selector is not applied
to the specificity of the scoped selector. However, since one
[`img`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element) selector is scoped, that selector is weighted more
strongly in the cascade with the application of [scope
proximity](#scope-proximity).

Many existing tools implement \"scoped
styles\" by applying a unique class or attribute to every element in a
given scope or \"single file component.\" In this example there are two
scopes (`main-component` and `sub-component`) and every element is
marked as part of one or both scopes using the `data-scope` attribute:

```
<section >
 <p >...<p>

 <!-- sub-component root is in both scopes -->
 <section >
 <!-- children are only in the inner scope -->
 <p >...<p>
 </section>
</section>
```

Those custom scope attributes are then appended to every single selector
in CSS:

``` highlight
p[data-scope~='main-component'] { color: red; }
p[data-scope~='sub-component'] { color: blue; }

/* both sections are part of the outer scope */
section[data-scope~='main-component'] { background: snow; }

/* the inner section is also part of the inner scope */
section[data-scope~='sub-component'] { color: ghostwhite; }
```

Using the [\@scope](#at-ruledef-scope) rule, authors and tools can replicate similar
behavior with the unique attribute or class applied only to the [scoping
roots](https://drafts.csswg.org/selectors-4/#scoping-root):

```
<section >
 <p>...<p>
 <section >
 <p>...<p>
 </section>
</section>
```

Then the class or attribute can be used for establishing both upper and
lower boundaries. Elements matched by a lower boundary selector are
excluded from the resulting scope, which allows authors to create
non-overlapping scopes by default:

``` highlight
@scope ([data-scope='main-component']) to ([data-scope]) {
 p { color: red; }

 /* only the outer section is part of the outer scope */
 section { background: snow; }
}

@scope ([data-scope='sub-component']) to ([data-scope]) {
 p { color: blue; }

 /* the inner section is only part of the inner scope */
 section { color: ghostwhite; }
}
```

However, authors can use the child combinator and universal selector to
create scope boundaries that overlap, such that the inner scope root is
part of both scopes:

``` highlight
@scope ([data-scope='main-component']) to ([data-scope] > *) {
 p { color: red; }

 /* both sections are part of the outer scope */
 section { background: snow; }
}
```

#### 3.5.2. Syntax of [\@scope]
The syntax of the
[\@scope](#at-ruledef-scope) rule is:

```
@scope <scope-boundaries>? {
 <block-contents>
}
```

with
[\<scope-boundaries\>](#typedef-scope-boundaries) defined as:

```
<scope-boundaries> = [ [ ( <scope-start> ) ]? [ to ( <scope-end> ) ]? ]!
```

and where:

- [[\<scope-start\>](#typedef-scope-start)] is a
 [\<selector-list\>](https://drafts.csswg.org/selectors-4/#typedef-selector-list)
 [selector](https://drafts.csswg.org/selectors-4/#selector) used to identify the [scoping
 root](https://drafts.csswg.org/selectors-4/#scoping-root)(s).

- [[\<scope-end\>](#typedef-scope-end)] is a
 [\<selector-list\>](https://drafts.csswg.org/selectors-4/#typedef-selector-list)
 [selector](https://drafts.csswg.org/selectors-4/#selector) used to identify any [scoping
 limits](#scoping-limit).

- the [qualified
 rules](https://drafts.csswg.org/css-syntax-3/#qualified-rule) within
 [\<block-contents\>](https://drafts.csswg.org/css-syntax-3/#typedef-block-contents), as well as any [nested
 declarations
 rules](https://drafts.csswg.org/css-nesting-1/#nested-declarations-rule) produced by [scoped
 declarations](#scoped-declarations), represents the [scoped style
 rules](#scoped-style-rules).

[Pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element) cannot be [scoping
roots](https://drafts.csswg.org/selectors-4/#scoping-root) or [scoping
limits](#scoping-limit); they
are invalid both within
[\<scope-start\>](#typedef-scope-start) and
[\<scope-end\>](#typedef-scope-end).

#### 3.5.3. Scoped Style Rules

[Scoped style rules] differ from non-scoped rules in the following
ways:

- Their selectors can only match elements that are [in
 scope](#in-scope). (This only
 applies to the
 [subject](https://drafts.csswg.org/selectors-4/#selector-subject); the rest of the selector can match unrestricted.)

- They accept a
 [\<relative-selector-list\>](https://drafts.csswg.org/selectors-4/#typedef-relative-selector-list) as their prelude (rather than just
 a
 [\<selector-list\>](https://drafts.csswg.org/selectors-4/#typedef-selector-list)). Such [relative
 selectors](https://drafts.csswg.org/selectors-4/#relative-selector) are relative to
 [:scope](https://drafts.csswg.org/selectors-4/#scope-pseudo).

- Any selector in the
 [\<relative-selector-list\>](https://drafts.csswg.org/selectors-4/#typedef-relative-selector-list) that does not start with a
 [combinator](https://drafts.csswg.org/selectors-4/#selector-combinator) but does [contain the nesting
 selector](https://drafts.csswg.org/css-nesting-1/#contain-the-nesting-selector) or the
 [:scope](https://drafts.csswg.org/selectors-4/#scope-pseudo) selector, is interpreted as a non-[relative
 selector](https://drafts.csswg.org/selectors-4/#relative-selector) (but the
 [subject](https://drafts.csswg.org/selectors-4/#selector-subject) must still be [in
 scope](#in-scope) to match).

By default, selectors in a [scoped
style rule](#scoped-style-rules) are [relative
selectors](https://drafts.csswg.org/selectors-4/#relative-selector), with the [scoping
root](https://drafts.csswg.org/selectors-4/#scoping-root) and [descendant
combinator](https://drafts.csswg.org/selectors-4/#descendant-combinator) implied at the start. The following selectors will
match the same elements:

``` highlight
@scope (#my-component) {
 p { color: green; }
 :scope p { color: green; }
}
```

Authors can adjust the implied relationship by adding an explicit
combinator:

``` highlight
@scope (#my-component) {
 > p { color: green; }
 :scope > p { color: green; }
}
```

Authors can also target or explicitly position the [scoping
root](https://drafts.csswg.org/selectors-4/#scoping-root) in a selector by including either
[:scope](https://drafts.csswg.org/selectors-4/#scope-pseudo) or
[&](https://drafts.csswg.org/css-nesting-1/#selectordef-) in a given selector:

``` highlight
@scope (#my-component) {
 :scope { border: thin solid; }
 & { border: thin solid; }

 main :scope p { color: green; }
 main & p { color: green; }
}
```

Both the
[:scope](https://drafts.csswg.org/selectors-4/#scope-pseudo) and
[&](https://drafts.csswg.org/css-nesting-1/#selectordef-) selectors match the [scope
root](https://drafts.csswg.org/selectors-4/#scoping-root), but with different
[specificity](https://drafts.csswg.org/selectors-4/#specificity): [:scope] has as
[specificity] of (0,1,0), whereas
[&] has a
[specificity] of 0.

#### 3.5.4. Identifying Scoping Roots and Limits

A [\@scope](#at-ruledef-scope) rule produces one or more
[scopes](#scope) as follows:

Finding the [scoping root](https://drafts.csswg.org/selectors-4/#scoping-root)(s)

: For each element matched by
 [\<scope-start\>](#typedef-scope-start), create a
 [scope](#scope) using that element
 as the [scoping
 root](https://drafts.csswg.org/selectors-4/#scoping-root). If no
 [\<scope-start\>] is
 specified, the [scoping root] is the
 [parent
 element](https://dom.spec.whatwg.org/#parent-element) of the [owner
 node](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-owner-node) of the stylesheet where the
 [\@scope](#at-ruledef-scope) rule is defined. (If no such element exists and
 the containing [node
 tree](https://dom.spec.whatwg.org/#concept-node-tree) is a [shadow
 tree](https://dom.spec.whatwg.org/#concept-shadow-tree), then the [scoping root]
 is the [shadow host]. Otherwise, the [scoping
 root] is the
 [root](https://dom.spec.whatwg.org/#concept-tree-root) of the containing [node
 tree].) Any
 [:scope](https://drafts.csswg.org/selectors-4/#scope-pseudo) or
 [&](https://drafts.csswg.org/css-nesting-1/#selectordef-) selectors in
 [\<scope-start\>] are
 interpreted as defined for its outer context.

Finding any [scoping limits](#scoping-limit)

: For each [scope](#scope) created by
 a [scoping
 root](https://drafts.csswg.org/selectors-4/#scoping-root), its [scoping
 limits](#scoping-limit) are
 set to all elements that are
 [descendants](https://dom.spec.whatwg.org/#concept-tree-descendant) of the [scoping root] and
 that match
 [\<scope-end\>](#typedef-scope-end), interpreting
 [:scope](https://drafts.csswg.org/selectors-4/#scope-pseudo) and
 [&](https://drafts.csswg.org/css-nesting-1/#selectordef-) exactly as in [scoped style
 rules](#scoped-style-rules).

Authors can establish local scoping
for
[`style`](https://html.spec.whatwg.org/multipage/semantics.html#the-style-element) elements by leaving out the
[\<scope-start\>](#typedef-scope-start) selector. For example:

```
<div>
 <style>
 @scope {
 p { color: red; }
 }
 </style>
 <p>this is red</p>
</div>
<p>not red</p>
```

That would be equivalent to:

```
<div id="foo">
 <style>
 @scope (#foo) {
 p { color: red; }
 }
 </style>
 <p>this is red</p>
</div>
<p>not red</p>
```

[Scoping
limits](#scoping-limit) can use
the
[:scope](https://drafts.csswg.org/selectors-4/#scope-pseudo) pseudo-class to require a specific relationship
to the [scoping
root](https://drafts.csswg.org/selectors-4/#scoping-root):

``` highlight
/* .content is only a limit when it is a direct child of the :scope */
@scope (.media-object) to (:scope > .content) { ... }
```

[Scoping limits](#scoping-limit) can also reference elements outside their [scoping
root](https://drafts.csswg.org/selectors-4/#scoping-root) by using
[:scope](https://drafts.csswg.org/selectors-4/#scope-pseudo). For example:

``` highlight
/* .content is only a limit when the :scope is inside .sidebar */
@scope (.media-object) to (.sidebar :scope .content) { ... }
```

#### 3.5.5. Scope Nesting

[\@scope](#at-ruledef-scope) rules can be nested. In this case, just as with the
nested style rules, the prelude selectors of the inner
[\@scope] (those defining its
[scope](#scope)) are [scoped
by](https://drafts.csswg.org/selectors-4/#scoped-selector) the selectors of the outer one.

 The resulting [scope](#scope) for further nested [scoped style
rules](#scoped-style-rules) is practically constrained by both the outer and inner
[\@scope](#at-ruledef-scope) rules, but the [scoping
root](https://drafts.csswg.org/selectors-4/#scoping-root) is defined by the innermost
[\@scope]. Since [scope
proximity](#scope-proximity)
is measured between a [scoped style rule]
[subject](https://drafts.csswg.org/selectors-4/#selector-subject) and [scoping root], only the
innermost [\@scope] matters for
determining [scope proximity] of [nested
\@scope rules](#scope-scope).

Should the scope proximity calculation
be impacted by nesting scopes? [\[Issue
#10795\]](https://github.com/w3c/csswg-drafts/issues/10795)

When nesting
[\@scope](#at-ruledef-scope) rules inside other
[\@scope] rules, or inside other
selectors, the
[\<scope-start\>](#typedef-scope-start) selector is [relative
to](https://drafts.csswg.org/selectors-4/#relative-selector) the nesting context, while the
[\<scope-end\>](#typedef-scope-end) and any [scoped style
rules](#scoped-style-rules) are [relative to] the
[scoping
root](https://drafts.csswg.org/selectors-4/#scoping-root) For example, the following code:

``` highlight
@scope (.parent-scope) {
 @scope (:scope > .child-scope) to (:scope .limit) {
 :scope .content {
 color: red;
 }
 }
}
```

is equivalent to:

``` highlight
@scope (.parent-scope > .child-scope) to (.parent-scope > .child-scope .limit) {
 .parent-scope > .child-scope .content {
 color: red;
 }
}
```

Global name-defining
[at-rules](https://drafts.csswg.org/css-syntax-3/#at-rule) such as
[\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes) or
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) or
[\@layer](https://drafts.csswg.org/css-cascade-5/#at-ruledef-layer) that are defined inside
[\@scope](#at-ruledef-scope) are valid, but are not scoped or otherwise affected
by the enclosing [\@scope] rule.
However, any [style
rules](https://drafts.csswg.org/css-syntax-3/#style-rule) contained by such rules (e.g. within
[\@layer]) are
[scoped](#scoped-style-rules).

#### 3.5.6. Scoped Declarations

[Declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) may be used directly with the body of a
[\@scope](#at-ruledef-scope) rule. Contiguous runs of
[declarations] are wrapped
in [nested declarations
rules](https://drafts.csswg.org/css-nesting-1/#nested-declarations-rule), which match the [scoping
root](https://drafts.csswg.org/selectors-4/#scoping-root) with zero
[specificity](https://drafts.csswg.org/selectors-4/#specificity).

``` highlight
@scope (.foo) {
 border: 1px solid black;
}
```

is equivalent to:

``` highlight
@scope (.foo) {
 :where(:scope) {
 border: 1px solid black;
 }
}
```

Just like for [style
rules](https://drafts.csswg.org/css-syntax-3/#style-rule),
[declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) and child
[rules](https://drafts.csswg.org/css-syntax-3/#css-rule) may be
[mixed](https://drafts.csswg.org/css-nesting-1/#mixing) within
[\@scope](#at-ruledef-scope).

### 3.6. Precedence of Non-CSS Presentational Hints

(#issue-d41d8cd9④) [CSS Cascading 5 § 6.4 Cascade
Layers](https://drafts.csswg.org/css-cascade-5/#layering)

## 4. CSSOM

### 4.1. The `CSSScopeRule` interface

The [`CSSScopeRule`](#cssscoperule) interface represents the
[\@scope](#at-ruledef-scope) rule:

```
[Exposed=Window]
interface CSSScopeRule : CSSGroupingRule {
 readonly attribute CSSOMString? start;
 readonly attribute CSSOMString? end;
};
```

`start` of type `CSSOMString`
: The `start` attribute returns the result of serializing the
 [\<scope-start\>](#typedef-scope-start) of the rule (without the
 enclosing parentheses), or null if there is no
 [\<scope-start\>].

`end` of type `CSSOMString`
: The `end` attribute returns the result of serializing the
 [\<scope-end\>](#typedef-scope-end) of the rule (without the enclosing
 parentheses), or null if there is no
 [\<scope-end\>].

## 5. Changes

This appendix is *informative*.

### 5.1. Changes since the 21 March 2023 Working Draft

Significant changes since the [21 March 2023 Working
Draft](https://www.w3.org/TR/2023/WD-css-cascade-6-20230321/) include:

- Added the `@import scope()` syntax, and the ability to specificy
 [layer()], [scope()], and
 [supports()](https://drafts.csswg.org/css-conditional-5/#funcdef-supports) in any order. ([Issue
 7348](https://github.com/w3c/csswg-drafts/issues/7348))

- Defined
 [&](https://drafts.csswg.org/css-nesting-1/#selectordef-) to behave like `:where(:scope)`. ([Issue
 9740](https://github.com/w3c/csswg-drafts/issues/9740))

- Allowed
 [declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) directly within
 [\@scope](#at-ruledef-scope). ([Issue
 10389](https://github.com/w3c/csswg-drafts/issues/10389))

- The
 [:scope](https://drafts.csswg.org/selectors-4/#scope-pseudo) selector can match the
 [featureless](https://drafts.csswg.org/selectors-4/#featureless) [shadow host] when that host is the
 [scoping
 root](https://drafts.csswg.org/selectors-4/#scoping-root) element. ([Issue
 9025](https://github.com/w3c/csswg-drafts/issues/9025))

- [[\<scope-start\>](#typedef-scope-start)] and
 [[\<scope-end\>](#typedef-scope-end)] selectors are unforgiving.
 ([Issue 10042](https://github.com/w3c/csswg-drafts/issues/10042))

- A [\@scope](#at-ruledef-scope) rule without
 [[\<scope-start\>](#typedef-scope-start)] scopes to the [shadow
 host] instead of the [shadow
 root](https://dom.spec.whatwg.org/#concept-shadow-root). ([Issue
 9178](https://github.com/w3c/csswg-drafts/issues/9178))

- Clarified that [scope
 proximity](#scope-proximity) is a single measurement of the steps between a single
 [scoping
 root](https://drafts.csswg.org/selectors-4/#scoping-root) and [scoped style
 rule](#scoped-style-rules)
 [subject](https://drafts.csswg.org/selectors-4/#selector-subject) ([Issue
 10795](https://github.com/w3c/csswg-drafts/issues/10795) has been
 opened to discuss this futher).

- Removed strong scope proximity. ([Issue
 6790](https://github.com/w3c/csswg-drafts/issues/6790))

- Removed the scoped descendant combinator (deferred). ([Issue
 8628](https://github.com/w3c/csswg-drafts/issues/8628))

- Added the [`CSSScopeRule`](#cssscoperule) interface. ([Issue
 8626](https://github.com/w3c/csswg-drafts/issues/8626))

### 5.2. Changes since the 21 December 2021 First Public Working Draft

Significant changes since the [21 December 2021 First Public Working
Draft](https://www.w3.org/TR/2021/WD-css-cascade-6-20211221/) include:

- Clarified [\@scope](#at-ruledef-scope) effects on nested
 [:scope](https://drafts.csswg.org/selectors-4/#scope-pseudo) and
 [&](https://drafts.csswg.org/css-nesting-1/#selectordef-) selectors. ([Issue
 8377](https://github.com/w3c/csswg-drafts/issues/8377))

- Removed [\@scope](#at-ruledef-scope) prelude from specificity calculation. ([Issue
 8500](https://github.com/w3c/csswg-drafts/issues/8500))

- Specified how name-defining
 [at-rules](https://drafts.csswg.org/css-syntax-3/#at-rule) behave in
 [\@scope](#at-ruledef-scope). ([Issue
 6895](https://github.com/w3c/csswg-drafts/issues/6895))

- Added implicit scopes by making
 [[\<scope-start\>](#typedef-scope-start)] optional. ([Issue
 6606](https://github.com/w3c/csswg-drafts/issues/6606))

- Disallowed
 [pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element) in the
 [\@scope](#at-ruledef-scope) prelude. ([Issue
 7382](https://github.com/w3c/csswg-drafts/issues/7382))

- Removed selector scoping notation. ([Issue
 7709](https://github.com/w3c/csswg-drafts/issues/7709))

- [Scoping limit](#scoping-limit) elements are excluded from the resulting
 [scope](#scope). ([Issue
 6577](https://github.com/w3c/csswg-drafts/issues/6577))

### 5.3. Additions Since Level 5

The following features have been added since [Level
5](https://www.w3.org/TR/css-cascade-5/):

- The definition of a [scope](#scope),
 as described by a combination of
 [\<scope-start\>](#typedef-scope-start) and
 [\<scope-end\>](#typedef-scope-end) selectors.

- The in-scope ([:in()]) pseudo-class for selecting with
 lower-boundaries

- The [\@scope](#at-ruledef-scope) rule for creating scoped stylesheets

- The definition of [scope
 proximity](#scope-proximity) in the cascade

### 5.4. Additions Since Level 4

The following features have been added since [Level
4](https://www.w3.org/TR/css-cascade-4/):

- Added [cascade
 layers](https://drafts.csswg.org/css-cascade-5/#cascade-layers) to the [cascade](#cascade) sort criteria (and defined style attributes as a
 distinct step of the [cascade] sort criteria so
 that they interact appropriately).

- Introduced the
 [\@layer](https://drafts.csswg.org/css-cascade-5/#at-ruledef-layer) rule for defining cascade layers.

- Added [layer]/[layer()] option to
 [\@import](#at-ruledef-import) definition.

- Introduced the
 [revert-layer](https://drafts.csswg.org/css-cascade-5/#valdef-all-revert-layer) keyword for rolling back values to previous
 layers.

### 5.5. Additions Since Level 3

The following features have been added since [Level
3](https://www.w3.org/TR/css-cascade-3/):

- Introduced
 [revert](https://drafts.csswg.org/css-cascade-5/#valdef-all-revert) keyword, for rolling back the cascade.

- Introduced
 [supports()](https://drafts.csswg.org/css-conditional-5/#funcdef-supports) syntax for supports-conditional
 [\@import](#at-ruledef-import) rules.

- Added [encapsulation
 context](#encapsulation-contexts) to the [cascade](#cascade) sort criteria to accommodate Shadow DOM.
 [\[DOM\]](#biblio-dom "DOM Standard")

- Defined the property two aliasing mechanisms CSS uses to support
 legacy syntaxes. See [CSS Cascading 4 § 3.1 Property
 Aliasing](https://drafts.csswg.org/css-cascade-4/#aliasing).

### 5.6. Additions Since Level 2

The following features have been added since [Level
2](http://www.w3.org/TR/CSS2/cascade.html):

- The
 [all](https://drafts.csswg.org/css-cascade-5/#propdef-all) shorthand
- The
 [initial](https://drafts.csswg.org/css-cascade-5/#valdef-all-initial) keyword
- The
 [unset](https://drafts.csswg.org/css-cascade-5/#valdef-all-unset) keyword
- Incorporation of animations and transitions into the
 [cascade](#cascade).

## [Acknowledgments]
David Baron, Tantek Çelik, Keith Grant, Giuseppe Gurgone, Theresa
O'Connor, Florian Rivoal, Noam Rosenthal, Simon Sapin, Jen Simmons,
Nicole Sullivan, Lea Verou, and Boris Zbarsky contributed to this
specification.

## 6. Privacy Considerations

- User preferences and UA defaults expressed via application of style
 rules are exposed by the cascade process, and can be inferred from the
 computed styles they apply to a document.

## 7. Security Considerations

- The cascade process does not distinguish between same-origin and
 cross-origin stylesheets, enabling the content of cross-origin
 stylesheets to be inferred from the computed styles they apply to a
 document.

- The [\@import](#at-ruledef-import) rule does not apply the [CORS
 protocol](https://fetch.spec.whatwg.org/#cors-protocol) to loading cross-origin stylesheets, instead allowing
 them to be freely imported and applied.

- The [\@import](#at-ruledef-import) rule assumes that resources without [`Content-Type`
 metadata](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#content-type)
 (or any same-origin file if the host document is in quirks mode) are
 `text/css`, potentially allowing arbitrary files to be imported into
 the page and interpreted as CSS, potentially allowing sensitive data
 to be inferred from the computed styles they apply to a document.
