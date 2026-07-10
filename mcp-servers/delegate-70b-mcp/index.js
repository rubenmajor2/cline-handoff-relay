#!/usr/bin/env node
// delegate-70b MCP server — offload cheap/bulk subtasks to local 70B vLLM
// idea #10156 / #10120 — Claude-head / 70B-body offload pattern
// Transport: stdio (spawned directly by Cline via command/args registration)

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

// ─── Config (all overridable via env) ─────────────────────────────────────────
const VLLM_BASE_URL = process.env.VLLM_URL ?? "http://localhost:8000/v1";
const VLLM_MODEL    = process.env.VLLM_MODEL ?? "llama-3.3-70b";
const TIMEOUT_MS    = parseInt(process.env.DELEGATE_TIMEOUT_MS ?? "60000", 10);
// ──────────────────────────────────────────────────────────────────────────────

const server = new Server(
  { name: "delegate-70b", version: "0.1.0" },
  { capabilities: { tools: {} } }
);

// ─── Tool manifest ─────────────────────────────────────────────────────────────
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "delegate_to_local_70b",
      description:
        "Offload bulk/cheap subtasks (summarize a long file, draft boilerplate, " +
        "extract structured data from large text, reformat, translate, classify) " +
        "to the free local Llama-3.3-70B running on the EMSU GPU box. " +
        "Returns plain text. Use this INSTEAD OF processing large text yourself " +
        "whenever: (1) the task is purely generative / transformative and does NOT " +
        "require Claude reasoning or tool use, (2) the input is long (>500 tokens), " +
        "or (3) the output quality of a 70B suffices. Saves Claude tokens to ~0 for " +
        "that subtask. NOT suitable for: tasks requiring tool calls, code execution, " +
        "or nuanced judgment that needs Claude-level reasoning.",
      inputSchema: {
        type: "object",
        properties: {
          prompt: {
            type: "string",
            description:
              "The full prompt to send to the 70B. Be explicit and self-contained — " +
              "the 70B has no prior conversation context. Include all relevant text " +
              "inline (e.g. paste the document to summarize directly in the prompt).",
          },
          task_type: {
            type: "string",
            description:
              "Optional hint for logging/routing: summarize | draft | extract | " +
              "reformat | translate | classify | other. Default: other.",
          },
          max_tokens: {
            type: "number",
            description:
              "Max tokens to generate. Default: 1024. Use higher for long drafts.",
          },
          temperature: {
            type: "number",
            description:
              "Sampling temperature. Default: 0.3 (factual/extractive tasks). " +
              "Use 0.7+ for creative drafts.",
          },
        },
        required: ["prompt"],
      },
    },
  ],
}));

// ─── Tool handler ──────────────────────────────────────────────────────────────
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  if (name !== "delegate_to_local_70b") {
    return {
      content: [{ type: "text", text: `Unknown tool: ${name}` }],
      isError: true,
    };
  }

  const {
    prompt,
    task_type = "other",
    max_tokens = 1024,
    temperature = 0.3,
  } = args;

  if (!prompt || typeof prompt !== "string" || prompt.trim().length === 0) {
    return {
      content: [{ type: "text", text: "Error: prompt is required and must be non-empty." }],
      isError: true,
    };
  }

  const endpoint = `${VLLM_BASE_URL}/chat/completions`;

  const body = JSON.stringify({
    model: VLLM_MODEL,
    messages: [{ role: "user", content: prompt }],
    max_tokens,
    temperature,
    stream: false,
    // Explicitly NO tools — plain completion only
  });

  // Abort controller for timeout
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

  let responseText;
  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        // vLLM doesn't require an API key by default; add if needed:
        // "Authorization": `Bearer ${process.env.VLLM_API_KEY ?? "none"}`,
      },
      body,
      signal: controller.signal,
    });

    clearTimeout(timer);

    if (!response.ok) {
      const errBody = await response.text().catch(() => "(no body)");
      return {
        content: [
          {
            type: "text",
            text: `Error: vLLM returned HTTP ${response.status} ${response.statusText}\n${errBody}`,
          },
        ],
        isError: true,
      };
    }

    const data = await response.json();

    // Validate shape
    const content = data?.choices?.[0]?.message?.content;
    if (typeof content !== "string") {
      return {
        content: [
          {
            type: "text",
            text: `Error: unexpected vLLM response shape.\n${JSON.stringify(data, null, 2)}`,
          },
        ],
        isError: true,
      };
    }

    responseText = content;
  } catch (err) {
    clearTimeout(timer);
    const isTimeout = err.name === "AbortError";
    return {
      content: [
        {
          type: "text",
          text: isTimeout
            ? `Error: vLLM request timed out after ${TIMEOUT_MS / 1000}s. ` +
              `Endpoint: ${endpoint}. ` +
              "Check that the GPU box is reachable and VLLM_URL env is correct."
            : `Error: ${err.message}\nEndpoint: ${endpoint}`,
        },
      ],
      isError: true,
    };
  }

  // Log to stderr for debugging (doesn't interfere with stdio MCP protocol)
  process.stderr.write(
    `[delegate-70b] task_type=${task_type} prompt_chars=${prompt.length} ` +
    `response_chars=${responseText.length} model=${VLLM_MODEL}\n`
  );

  return {
    content: [{ type: "text", text: responseText }],
  };
});

// ─── Startup self-cleanup (zombie process prevention) ─────────────────────────
// Cline spawns a new process per window but doesn't kill old ones when windows
// close. Kill any OTHER delegate-70b-mcp/index.js processes on boot.
(function killZombies() {
  try {
    const { execSync } = require("node:child_process");
    const myPid = process.pid;
    const result = execSync(
      `ps aux | grep "delegate-70b-mcp/index.js" | grep -v grep | awk '{print $2}'`,
      { encoding: "utf8", stdio: ["pipe", "pipe", "ignore"] }
    );
    const pids = result.trim().split("\n").map(Number).filter(p => p && p !== myPid);
    for (const pid of pids) { try { process.kill(pid, "SIGTERM"); } catch {} }
    if (pids.length > 0) {
      process.stderr.write(`[delegate-70b] startup cleanup: killed ${pids.length} zombie(s): ${pids.join(", ")}\n`);
    }
  } catch {}
})();

// ─── Start ─────────────────────────────────────────────────────────────────────
const transport = new StdioServerTransport();
await server.connect(transport);
process.stderr.write(
  `[delegate-70b] MCP server ready. VLLM_URL=${VLLM_BASE_URL} MODEL=${VLLM_MODEL}\n`
);
