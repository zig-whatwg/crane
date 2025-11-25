// Property Setter Tests
// Tests that property setters work correctly

// Test: element.id setter
(() => {
    const doc = new Document();
    const element = doc.createElement("div");
    element.id = "my-id";
    return element.id === "my-id";
})()

// Test: element.className setter
(() => {
    const doc = new Document();
    const element = doc.createElement("div");
    element.className = "my-class";
    return element.className === "my-class";
})()

// Test: set both id and className
(() => {
    const doc = new Document();
    const div = doc.createElement("div");
    div.id = "test-id";
    div.className = "test-class";
    return div.id === "test-id" && div.className === "test-class";
})()

// Test: set property multiple times
(() => {
    const doc = new Document();
    const div = doc.createElement("div");
    div.id = "first";
    if (div.id !== "first") return false;
    div.id = "second";
    if (div.id !== "second") return false;
    div.id = "third";
    return div.id === "third";
})()

// Test: empty string setter
(() => {
    const doc = new Document();
    const div = doc.createElement("div");
    div.id = "initial";
    div.id = "";
    return div.id === "";
})()

// Test: numeric value coercion
(() => {
    const doc = new Document();
    const div = doc.createElement("div");
    div.id = 123;
    return div.id === "123";
})()
