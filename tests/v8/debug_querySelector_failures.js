// Debug querySelector failures - verbose output

var doc = new Document();
var body = doc.createElement("body");

var header = doc.createElement("header");
var main = doc.createElement("main");
var footer = doc.createElement("footer");
var div1 = doc.createElement("div");
var div2 = doc.createElement("div");
var div3 = doc.createElement("div");
var section1 = doc.createElement("section");
var section2 = doc.createElement("section");
var article = doc.createElement("article");
var p = doc.createElement("p");
var span = doc.createElement("span");
var a = doc.createElement("a");
var button = doc.createElement("button");
var input = doc.createElement("input");

var _1 = body.appendChild(header);
var _2 = body.appendChild(main);
var _3 = main.appendChild(section1);
var _4 = main.appendChild(section2);
var _5 = section1.appendChild(div1);
var _6 = section1.appendChild(div2);
var _7 = section2.appendChild(div3);
var _8 = section2.appendChild(article);
var _9 = article.appendChild(p);
var _10 = p.appendChild(span);
var _11 = div1.appendChild(a);
var _12 = div2.appendChild(button);
var _13 = div3.appendChild(input);
var _14 = body.appendChild(footer);

// Test child combinator
console.log("Testing child combinator selectors...")

assert.strictEqual(body.querySelector("body > header"), header, "body > header === header")
assert.strictEqual(body.querySelector("body > main"), main, "body > main === main")
assert.strictEqual(body.querySelector("body > footer"), footer, "body > footer === footer")
assert.strictEqual(body.querySelector("main > section"), section1, "main > section === section1")
assert.strictEqual(body.querySelector("section > div"), div1, "section > div === div1")
assert.strictEqual(body.querySelector("article > p"), p, "article > p === p")
assert.strictEqual(body.querySelector("p > span"), span, "p > span === span")

// Multi-level child
assert.strictEqual(body.querySelector("main > section > div"), div1, "main > section > div === div1")
assert.strictEqual(body.querySelector("section > article > p"), p, "section > article > p === p")

// Child vs descendant
assert.strictEqual(body.querySelector("body > section"), null, "body > section === null")

// querySelectorAll tests
console.log("Testing querySelectorAll...")

assert.strictEqual(body.querySelectorAll("section").length, 2, "querySelectorAll('section').length === 2")
assert.strictEqual(body.querySelectorAll("div").length, 3, "querySelectorAll('div').length === 3")
assert.strictEqual(body.querySelectorAll("main section").length, 2, "querySelectorAll('main section').length === 2")
assert.strictEqual(body.querySelectorAll("section, div").length, 5, "querySelectorAll('section, div').length === 5")

console.log("All debug querySelector tests complete")
