# 291 - MCP Tool Call Pre-Dispatch Validation

**Purpose:**  
Prevent Cline from dispatching MCP tool calls that will fail due to: misspelled tool names, hallucinated (non-existent) tools, type mismatches (string vs number), missing required arguments, or XML tag corruption in tool names. This rule eliminates ~5-10% of tool-call failures that are pure input validation errors.

## Error Patterns This Prevents

| Error Class | Example | Root Cause |
|---|---|---|
| **Tool name typo** | `clinrerules_reindex` → ERROR | Agent mis-typed `clinerules` |
| **Hallucinated tool** | `send_email` → ERROR | Tool doesn't exist on any server |
| **XML tag corruption** | `bug_library_record</tool_process>` → ERROR | Closing XML tag leaked into tool name |
| **String vs number** | `limit:"50"` → ERROR (schema expects number) | JSON form passes quoted strings |
| **Missing required arg** | `description: undefined` → ERROR | Agent omitted a required field |

## Detection — Pre-Dispatch Checklist

Before calling ANY MCP tool via `use_mcp_tool`, verify:

1. **Tool name exists** — The tool name matches exactly what's in the MCP server's tool list (from the system prompt or `list_tools`). If the tool name is longer than 2 words and you typed it from memory, double-check it.
2. **Tool name is clean** — No trailing `</...>`, `>`, or XML tag fragments. Strip them if present.
3. **Server name is correct** — The `server_name` matches a connected MCP server exactly (e.g., `clinerules`, not `clinrerules`; `emsu-operations`, not `emsu-operationss`).
4. **All required args present** — Check the tool's JSON Schema. If a param is required (`"required": [...]`), it MUST be present and non-undefined.
5. **Types match** — Numbers must be numbers (not quoted strings), booleans must be true/false (not `"true"`), objects must be `{}` (not null/undefined). Cast as needed.

## Common Hallucinated Tools → Real Tool Map

| Hallucinated Call | Correct Call |
|---|---|
| `send_email` (emsu-operations) | `agent_send_or_draft` (emsu-operations) — for email |
| `grep_server_file` (emsu-operations) | `ssh_command` with `grep` on the server |
| `read_server_log` (emsu-operations) | `check_server_logs` |
| `create_ticket` (emsu-operations) | Use `add_ticket_comment` on existing, or create via Orchestrator |
| `search_emails` (emsu-operations) | `check_student_comms` (for student emails) |
| `get_server_file` (emsu-operations) | `read_server_file` |
| `clinrerules_reindex` (clinerules) | `clinerules_reindex` |
| `clinernules_lookup` (clinerules) | `clinerules_lookup` |

## Type Coercion Rules

When calling `use_mcp_tool`, ensure these types match:

- **Numbers:** Never quote. `42` not `"42"`. Cast with `parseInt()` or `Number()`.
- **Booleans:** `true` / `false`, never `"true"` or `1`.
- **Arrays:** `[...]`, never `"[...]"` (a JSON string).
- **Objects:** `{...}`, never `undefined` or `null` if required.
- **Required fields:** If the schema says `required: ["description"]`, always include it.

## Recovery On Error

If you see `MCP error -32602: Tool <name> not found`:
1. Check if the tool name has a typo (Levenshtein distance test).
2. Check if the tool exists on the server at all (review the tool list in your system prompt).
3. If the tool doesn't exist, use the "Hallucinated Tools → Real Tool Map" above.
4. Do NOT retry with the same wrong name.

If you see `MCP error -32602: Input validation error: expected number, received string`:
1. Find the offending argument in the error message.
2. Remove quotes: change `"50"` → `50`, `"17846"` → `17846`.
3. Retry with corrected type.

## References
- Rule 150 — MCP Downtime Handling (for actual downtime, not input validation errors)
- Rule 261 — MCP Failure Classification (server-down vs session-expired vs transport vs transient)
- Bug Library: frankenstein_router_incidents #1767-#1770
- Idea #17846 (infra-level fix for type coercion + tool name validation)

---

**Definition-of-Done:**  
- Agent checks tool name against server's known tool list before dispatch.
- Agent strips XML tag fragments from tool names.
- Agent ensures numbers are unquoted, required fields are present.
- New rule indexed in clinerules MCP.
- Bug library entries #1767-#1770 recorded for future agents.