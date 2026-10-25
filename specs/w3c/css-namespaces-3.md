## 1. Introduction

*This section is non-normative.*

This CSS Namespaces module defines syntax for using namespaces in CSS.
It defines the
[\@namespace](#at-ruledef-namespace) rule for declaring a default namespace and for
binding namespaces to namespace prefixes. It also defines a syntax for
using those prefixes to represent namespace-qualified names. It does not
define where such names are valid or what they mean: that depends on
their context and is defined by a host language, such as Selectors
([\[SELECT\]](#biblio-select "Selectors Level 3")),
that references the syntax defined in the CSS Namespaces module.

Note that a CSS client that does not support this module will (if it
properly conforms to [CSS's forward-compatible parsing
rules](https://www.w3.org/TR/CSS21/syndata.html#parsing-errors)) ignore
all [\@namespace](#at-ruledef-namespace) rules, as well as all style rules that make use
of namespace qualified names. The syntax of delimiting namespace
prefixes in CSS was deliberately chosen so that these CSS clients would
ignore the style rules rather than possibly match them incorrectly.

### 1.1. Terminology

Besides terms introduced by this specification, CSS Namespaces uses the
terminology defined in Namespaces in XML 1.0.
[\[XML-NAMES\]](#biblio-xml-names "Namespaces in XML 1.0 (Third Edition)")
However, the syntax defined here is not restricted to representing XML
element and attribute names and may represent other kinds of namespaces
as defined by the host language.

In CSS Namespaces a namespace name consisting of the empty string is
taken to represent the null namespace or lack of a namespace.

For example, given the namespace
declarations:

 @namespace empty "";
 @namespace "";

The [type
selectors](https://drafts.csswg.org/selectors-4/#type-selector) `elem`, `|elem`, and `empty|elem` are equivalent.

## 2. Declaring namespaces: the [\@namespace rule]
The [\@namespace]
[at-rule](https://drafts.csswg.org/css-syntax-3/#at-rule) declares a namespace prefix and associates it with a
given namespace name (a string). This namespace prefix can then be used
in namespace-qualified names such as the [CSS qualified
names](#css-qualified-name)
defined below.

@namespace "http://www.w3.org/1999/xhtml";
 @namespace svg "http://www.w3.org/2000/svg";

The first rule declares a default namespace
`http://www.w3.org/1999/xhtml` to be applied to names that have no
explicit namespace component.

The second rule declares a namespace prefix `svg` that is used to apply
the namespace `http://www.w3.org/2000/svg` where the `svg` namespace
prefix is used.

In CSS Namespaces, as in Namespaces in XML 1.0, the prefix is merely a
syntactic construct; it is the [expanded name] (the tuple of local name and
namespace name) that is significant. Thus the actual prefixes used in a
CSS style sheet, and whether they are defaulted or not, are independent
of the namespace prefixes used in the markup and whether these are
defaulted or not.

For example, given the following XML
document:

 <qml:elem xmlns:qml="http://example.com/q-markup"></qml:elem>

and the following
[\@namespace](#at-ruledef-namespace) declarations at the beginning of a CSS file:

 @namespace Q "http://example.com/q-markup";
 @namespace lq "http://example.com/q-markup";

The selectors [Q\|elem] and [lq\|elem] in that CSS file
would both match the element `<qml:elem>`.

(The selector [qml\|elem] would be invalid, because CSS namespaces
only recognize prefixes declared in CSS, not those declared by the
document language.)

### 2.1. Syntax

The syntax for the
[\@namespace](#at-ruledef-namespace) rule is:

 @namespace <namespace-prefix>? [ <string> | <url> ] ;

 <namespace-prefix> = <ident>

Any [\@namespace](#at-ruledef-namespace) rules must follow all \@charset and \@import
rules and precede all other non-ignored at-rules and style rules in a
style sheet. For CSS syntax this adds
`[ namespace [S``CDO``CDC]* ]*` immediately after
`[ import [S``CDO``CDC]* ]*` in the `stylesheet` grammar.

A syntactically invalid
[\@namespace](#at-ruledef-namespace) rule (whether malformed or misplaced) must be
[ignored](https://www.w3.org/TR/CSS21/conform.html#ignore). A CSS [style
sheet](https://www.w3.org/TR/CSS21/conform.html#style-sheet) containing
an invalid [\@namespace] rule is
not a [valid style
sheet](https://www.w3.org/TR/CSS21/conform.html#valid-style-sheet).

A URI string parsed from the `URI` syntax must be treated as a literal
string: as with the `STRING` syntax, no URI-specific normalization is
applied.

All strings---​including the empty string and strings representing
invalid URIs---​are valid namespace names in
[\@namespace](#at-ruledef-namespace) declarations.

### 2.2. Scope

The namespace prefix is declared only within the style sheet in which
its [\@namespace](#at-ruledef-namespace) rule appears. It is not declared in any style
sheets importing or imported by that style sheet, nor in any other style
sheets applying to the document.

### 2.3. Declaring Prefixes

A [namespace prefix], once declared, represents the namespace for which it was
declared and can be used to indicate the namespace of a
namespace-qualified name. Namespace prefixes are, [like CSS counter
names](https://www.w3.org/TR/CSS21/syndata.html#counter),
case-sensitive.

If in the namespace declaration the namespace prefix is omitted, then
the namespace so declared is the default namespace. The [default
namespace] may apply to names that have no explicit namespace prefix:
modules that employ namespace prefixes must define in which contexts the
default namespace applies. For example, following
[\[XML-NAMES\]](#biblio-xml-names "Namespaces in XML 1.0 (Third Edition)"),
in Selectors
[\[SELECT\]](#biblio-select "Selectors Level 3") the
default namespace applies to type selectors---​but it does not apply to
attribute selectors. There is no default value for the default
namespace: modules that assign unqualified names to the default
namespace must define how those unqualified names are to be interpreted
when no default namespace is declared.

 Note that using default namespaces in conjunction with
type selectors can cause UAs that support default namespaces and UAs
that don't support default namespaces to interpret selectors
differently.

If a namespace prefix or default namespace is declared more than once
only the last declaration shall be used. Declaring a namespace prefix or
default namespace more than once is nonconforming.

## 3. CSS Qualified Names

A [CSS qualified name] is a name explicitly located within
(associated with) a namespace. To form a qualified name in CSS syntax, a
namespace prefix that has been declared within scope is prepended to a
local name (such as an element or attribute name), separated by a
\"vertical bar\" (`|`, U+007C). The prefix, representing the namespace
for which it has been declared, indicates the namespace of the local
name. The prefix of a qualified name may be omitted to indicate that the
name belongs to no namespace, i.e. that the namespace name part of the
expanded name has no value. Some contexts (as defined by the host
language) may allow the use of an asterisk (`*`, U+002A) as a wildcard
prefix to indicate a name in any namespace, including no namespace.

Given the namespace declarations:

 @namespace toto "http://toto.example.org";
 @namespace "http://example.com/foo";

In a context where the default namespace applies

`toto|A`
: represents the name `A` in the `http://toto.example.org` namespace.

`|B`
: represents the name `B` that belongs to no namespace.

`*|C`
: represents the name `C` in any namespace, including no namespace.

`D`
: represents the name `D` in the `http://example.com/foo` namespace.

The syntax for the portion of a CSS qualified name before the local name
is given below, both for qualified names that allow wildcard prefixes
(`wqname`) and for qualified names that disallow wildcard prefixes
(`qname`). (The syntax uses notation from the [Grammar appendix of CSS
2.1](https://www.w3.org/TR/CSS21/grammar.html).
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
Note this means that comments, but not white space, are implicitly
allowed between tokens.):

 qname_prefix
 : namespace_prefix? '|'
 ;
 wqname_prefix
 : [ namespace_prefix? | '*' ] '|'
 ;
 qname
 : qname_prefix? ident
 ;
 wqname
 : wqname_prefix? ident
 ;
 wqwname
 : wqname_prefix? [ ident | '*' ]
 ;

CSS qualified names can be used in (for example) selectors and property
values as described in other modules. Those modules must define handling
of namespace prefixes that have not been properly declared. Such
handling should treat undeclared namespace prefixes as a parsing error
that will cause the selector or declaration (etc.) to be considered
invalid and, in CSS,
[ignored](https://www.w3.org/TR/CSS21/conform.html#ignore).

For example, the Selectors module
[\[SELECT\]](#biblio-select "Selectors Level 3")
defines a type selector with an undeclared namespace prefix to be an
invalid selector, and CSS
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
requires style rules with an invalid selector to be completely ignored.

## [ Changes]
Changes made since the [29 September 2011
Recommendation](https://www.w3.org/TR/2011/REC-css3-namespace-20110929/):

- Added predefined [qname], [wqname], and [wqwname]
 productions, to make those constructs easier for other specs to use.

## [ Acknowledgments]
This draft borrows heavily from earlier drafts on CSS namespace support
by Chris Lilley and by Peter Linss and early (unpublished) drafts on CSS
and XML by Håkon Lie and Bert Bos, and XML Namespaces and CSS by Bert
Bos and Steven Pemberton. Many current and former members of the CSS
Working Group have contributed to this document. Discussions on
www-style@w3.org and in other places have also contributed ideas to this
specification. Special thanks goes to L. David Baron, Karl Dubost, Ian
Hickson, Björn Höhrmann, and Lachlan Hunt for their comments.

## [Privacy Considerations]
No new privacy considerations have been reported on this specification.

## [Security Considerations]
No new security considerations have been reported on this specification.
