const fs = require("fs");
const path = require("path");
const vm = require("vm");

const utilsCode = fs.readFileSync(
  path.join(__dirname, "../package/contents/ui/utils.js"),
  "utf8"
);

const ctx = {};
vm.createContext(ctx);
vm.runInContext(utilsCode, ctx);

const { buildModelList, buildModelListFromConfig } = ctx;

let passed = 0;
let failed = 0;

function assert(condition, msg) {
  if (condition) {
    passed++;
  } else {
    failed++;
    console.error("FAIL: " + msg);
  }
}

function assertEq(actual, expected, msg) {
  if (JSON.stringify(actual) === JSON.stringify(expected)) {
    passed++;
  } else {
    failed++;
    console.error(
      "FAIL: " + msg + "\n  expected: " + JSON.stringify(expected) + "\n  actual:   " + JSON.stringify(actual)
    );
  }
}

const providerData = {
  all: [
    {
      id: "opencode-go",
      name: "Opencode",
      enabled: true,
      models: {
        "gpt-4o": { name: "GPT-4o" },
        "claude-sonnet": { name: "Claude Sonnet" },
      },
    },
    {
      id: "ollama",
      name: "Ollama",
      enabled: true,
      models: {
        llama3: { name: "Llama 3" },
      },
    },
    {
      id: "disabled-provider",
      name: "Disabled",
      enabled: false,
      models: { m1: { name: "M1" } },
    },
  ],
  connected: ["opencode-go", "ollama"],
};

const result = buildModelList(providerData, []);

assert(result.length === 3, "should have 3 models (disabled provider excluded)");
assertEq(result[0].value, "opencode-go/gpt-4o", "opencode-go sorted first");
assertEq(result[1].value, "opencode-go/claude-sonnet", "opencode-go second model");
assertEq(result[2].value, "ollama/llama3", "ollama model last");

const withRecent = buildModelList(providerData, ["ollama/llama3"]);
assertEq(withRecent[0].value, "ollama/llama3", "recent model first");
assert(withRecent[0].providerName === "\u2B50 Recent", "recent model has star label");
assertEq(withRecent.length, 3, "total count unchanged with recent");

const noModels = buildModelList({}, []);
assertEq(noModels.length, 1, "empty data returns fallback");
assertEq(noModels[0].value, "", "fallback has empty value");

const noFilterResult = buildModelList(
  { all: [{ id: "p1", name: "P1", enabled: true, models: { m1: { name: "M1" } } }] },
  []
);
assertEq(noFilterResult.length, 1, "works without connected filter");

const providerNoModels = buildModelList(
  { all: [{ id: "p1", name: "P1", enabled: true }], connected: ["p1"] },
  []
);
assertEq(providerNoModels[0].value, "p1/default", "provider without models gets default");

const configData = {
  providers: {
    "opencode-go": {
      name: "Opencode",
      models: { "gpt-4o": { name: "GPT-4o" } },
    },
    ollama: {
      name: "Ollama",
      models: { llama3: { name: "Llama 3" } },
    },
  },
};

const configResult = buildModelListFromConfig(configData, []);
assert(configResult.length === 2, "config: 2 models from providers");
assertEq(configResult[0].value, "opencode-go/gpt-4o", "config: opencode-go sorted first");

const configRecent = buildModelListFromConfig(configData, ["ollama/llama3"]);
assertEq(configRecent[0].value, "ollama/llama3", "config: recent model first");

const emptyConfig = buildModelListFromConfig({ providers: {} }, []);
assertEq(emptyConfig.length, 1, "config: empty providers returns fallback");

const configProviderNoModels = buildModelListFromConfig(
  { providers: { p1: { name: "P1", models: {} } } },
  []
);
assertEq(configProviderNoModels[0].value, "p1/default", "config: empty models gets default");

const manyRecent = buildModelList(
  providerData,
  ["ollama/llama3", "opencode-go/gpt-4o", "opencode-go/claude-sonnet"]
);
assertEq(manyRecent[0].value, "ollama/llama3", "multiple recent: first recent first");
assertEq(manyRecent[1].value, "opencode-go/gpt-4o", "multiple recent: second recent second");
assertEq(manyRecent[2].value, "opencode-go/claude-sonnet", "multiple recent: third recent third");
assertEq(manyRecent.length, 3, "multiple recent: no duplicates");

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed > 0 ? 1 : 0);
