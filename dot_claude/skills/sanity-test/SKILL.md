---
description: "Sanity-test scripts by extracting testable units (jq expressions, parameter expansions, key functions) and running them against mock data (normal, empty, null, partial, malformed, error conditions). Use when reviewing bash or python scripts and you want to verify logic handles edge cases, or when the user asks to \"sanity test\", \"test with mock data\", or \"verify edge cases\" for a script."
allowed-tools: ["Bash", "AskUserQuestion"]
user-invocable: true
---

# Sanity Test

Test scripts by extracting key logic and running it against mock data to verify edge case handling.

## Step 1: Resolve the target

The argument (ARGUMENTS) can be:
- **A file path**: Read the file directly
- **An MR number or URL**: Extract the MR number, run `glab mr diff <number> --raw > /tmp/sanity-test-diff.txt`, read the diff to identify changed files, then read those files from disk for full context
- **No argument**: Check if there's an unstaged diff (`git diff`), or ask the user what to test

Determine the **language** from shebang, file extension, or diff file paths.

## Step 2: Extract testable units

Read the target file(s) or diff. Identify **testable units** — isolated expressions or functions whose behavior can be verified independently with mock input.

### Bash scripts
- **jq expressions**: Extract the full `jq` filter string and identify what JSON structure it expects
- **Parameter expansions**: `${var%% *}`, `${var##* }`, `${var:-default}`, etc.
- **Pipelines**: `curl ... | jq ... | awk ...` — test the data-transformation stages individually
- **Conditional logic**: `[[ -z "$var" ]]`, arithmetic comparisons, date parsing
- **Functions that transform data**: Identify input → output contracts

### Python scripts
- **Key functions**: Functions that parse, transform, or validate data
- **List/dict comprehensions**: Complex transformations
- **Exception handlers**: What happens when inputs are wrong
- **String formatting / regex**: Pattern matching logic

For each unit, note:
- What it does (one line)
- What input it expects
- What downstream code consumes its output

## Step 3: Design test cases

For each testable unit, design test cases across these categories:

| Category | What to test |
|----------|-------------|
| **Happy path** | Normal, expected input |
| **Empty/null** | Empty strings, null values, empty arrays/objects, `None` |
| **Partial data** | Some fields present, others missing or null |
| **Malformed input** | Wrong type entirely (HTML instead of JSON, string instead of number) |
| **Boundary values** | Zero, negative, very long strings, special characters |
| **Error propagation** | What happens when this unit fails — does the caller handle it? |

Not every category applies to every unit. Skip categories that aren't relevant or realistic for a given unit.

## Step 4: Present the test plan

Use the `AskUserQuestion` tool to present the test plan and ask for approval.

Format as a numbered list grouped by testable unit:

```
Unit 1: <description>
  1. Happy path: <input> → expected <output>
  2. Empty input: <input> → expected <output>
  3. Null field: <input> → expected <output>

Unit 2: <description>
  1. Happy path: ...
```

Options: "Run all tests", "Let me pick which to run", "Modify the plan"

## Step 5: Execute tests

Run each approved test case.

**Bash**: Use `echo '<mock_json>' | jq '<filter>'` for jq expressions, bash subshells `( var="<mock>"; echo "${var%% *}" )` for parameter expansions. Capture stdout and exit code.

**Python**: Use `python3 -c "..."` with extracted functions/expressions and mock input. For complex logic, write a temp test file.

**Run independent tests in parallel** using multiple Bash tool calls.

For each test, record: input, actual output, exit code, whether it matches expectations.

## Step 6: Trace downstream impact

For any test that produced unexpected output (empty when data expected, wrong exit code, etc.):

1. Read the calling code to understand what it does with the output
2. Determine if unexpected output causes a problem downstream:
   - Does the caller have a safe default / fallback?
   - Could it cause a crash, silent data loss, or wrong decision?
3. Classify: **safe** (handled), **risky** (could cause issues), or **bug** (definitely wrong)

## Step 7: Report results

Output a results table:

| # | Unit | Scenario | Input (summary) | Output | Exit | Impact |
|---|------|----------|-----------------|--------|------|--------|

Then summarize:
- Total tests: run / passed / unexpected
- Any **risky** or **bug** findings with explanation
- Recommendations (if any)

## Step 8: Clean up

Remove any temp files created during testing (`/tmp/sanity-test-*`).
