#!/usr/bin/env node
// Unit tests for utils.js — pure JS, no Qt dependency
const fs = require("fs");
const path = require("path");

const utilsPath = path.resolve(
  __dirname,
  "../package/contents/ui/utils.js",
);
const utilsCode = fs.readFileSync(utilsPath, "utf8");
eval(utilsCode);

let pass = 0;
let fail = 0;

function test(name, fn) {
  try {
    fn();
    pass++;
  } catch (e) {
    fail++;
    console.log("  FAIL:", name, "-", e.message);
  }
}

function compare(a, b) {
  if (a !== b)
    throw new Error("expected " + JSON.stringify(b) + " got " + JSON.stringify(a));
}
function verify(v) {
  if (!v) throw new Error("assertion failed");
}

console.log("  unit tests from utils.js");

// -- extractReply --
test("extractReply text", () => compare(extractReply({ text: "hello" }), "hello"));
test("extractReply content string", () =>
  compare(extractReply({ content: "world" }), "world"));
test("extractReply content object", () =>
  compare(extractReply({ content: { foo: "bar" } }), '{"foo":"bar"}'));
test("extractReply message", () => compare(extractReply({ message: "hi" }), "hi"));
test("extractReply parts", () =>
  compare(extractReply({ parts: [{ type: "text", text: "abc" }] }), "abc"));
test("extractReply parts skip non-text", () =>
  compare(
    extractReply({
      parts: [
        { type: "tool", text: "x" },
        { type: "text", text: "y" },
      ],
    }),
    "y",
  ));
test("extractReply tokens", () =>
  compare(extractReply({ tokens: "tok" }), "tok"));
test("extractReply fallback", () =>
  compare(extractReply({ unknown: "val" }), '{"unknown":"val"}'));
test("extractReply empty parts", () => compare(extractReply({ parts: [] }), ""));
test("extractReply text priority", () =>
  compare(extractReply({ text: "a", content: "b" }), "a"));

// -- buildModelList --
test("buildModelList empty", () => {
  const r = buildModelList({});
  compare(r.length, 1);
  compare(r[0].display, "No models found");
});

test("buildModelList providers", () => {
  const r = buildModelList({
    providers: [
      { id: "a", name: "A", models: { m1: { name: "M1" }, m2: {} } },
      { id: "b", name: "B", models: { m3: { name: "M3" } } },
    ],
  });
  compare(r.length, 3);
  compare(r[0].value, "a/m1");
  compare(r[1].value, "a/m2");
  compare(r[2].value, "b/m3");
});

test("buildModelList disabled", () => {
  const r = buildModelList({
    providers: [
      { id: "x", name: "X", enabled: false, models: { m1: { name: "M1" } } },
      { id: "y", name: "Y", models: { m2: { name: "M2" } } },
    ],
  });
  compare(r.length, 1);
  compare(r[0].value, "y/m2");
});

test("buildModelList no models", () => {
  const r = buildModelList({ providers: [{ id: "a", name: "A" }] });
  compare(r.length, 1);
  compare(r[0].value, "a/default");
});

test("buildModelList empty providers", () => {
  const r = buildModelList({ providers: [] });
  compare(r.length, 1);
  compare(r[0].display, "No models found");
});

test("buildModelList new API format with connected filter", () => {
  const r = buildModelList({
    all: [
      { id: "a", name: "A", models: { m1: { name: "M1" } } },
      { id: "b", name: "B", models: { m2: { name: "M2" } } },
      { id: "c", name: "C", models: { m3: { name: "M3" } } },
    ],
    connected: ["a", "c"],
  });
  compare(r.length, 2);
  compare(r[0].value, "a/m1");
  compare(r[1].value, "c/m3");
});

test("buildModelList new API format no connected filter", () => {
  const r = buildModelList({
    all: [
      { id: "a", name: "A", models: { m1: { name: "M1" } } },
    ],
  });
  compare(r.length, 1);
  compare(r[0].value, "a/m1");
});

test("buildModelList new API format filters out unconnected", () => {
  const r = buildModelList({
    all: [
      { id: "x", name: "X", models: { m1: { name: "M1" } } },
    ],
    connected: ["y"],
  });
  compare(r.length, 1);
  compare(r[0].display, "No models found");
});

// -- buildModelListFromConfig --
test("buildModelListFromConfig", () => {
  const r = buildModelListFromConfig({
    providers: {
      a: { name: "A", models: { m1: { name: "M1" } } },
      b: { name: "B", models: {} },
    },
  });
  compare(r.length, 2);
  compare(r[0].value, "a/m1");
  compare(r[1].value, "b/default");
});

// -- addMessage --
test("addMessage appends", () => {
  const orig = [{ role: "user", text: "hi", time: "12:00" }];
  const r = addMessage("assistant", "world", orig);
  compare(r.length, 2);
  compare(r[0].role, "user");
  compare(r[1].role, "assistant");
  verify(r[1].time !== undefined);
  compare(orig.length, 1); // immutable
});

test("addMessage empty", () => {
  const r = addMessage("user", "first", []);
  compare(r.length, 1);
  compare(r[0].role, "user");
  compare(r[0].text, "first");
});

// -- formatTime --
test("formatTime", () => {
  compare(formatTime(new Date(2024, 0, 1, 9, 5)), "09:05");
  compare(formatTime(new Date(2024, 0, 1, 23, 59)), "23:59");
});

console.log("  Results: " + pass + " passed, " + fail + " failed");
process.exit(fail > 0 ? 1 : 0);
