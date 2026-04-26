# The Ship's AI Architecture: Captain, Firstmate, and Matey

Welcome to the central repository for the Ship's AI Architecture. This repository contains all the configurations, prompts, wrapper scripts, and documentation needed to deploy our highly optimized, multi-agent AI system on a fresh machine.

## 1. Binaries and MCP Servers in Use

### Core Binaries
*   **`hal-bin`** (Kit Binary): The core agent framework powering all interactions.
*   **`llama-server`** (llama.cpp): The local inference engine running the Gemma 27B model.
*   **`sqlite3`**: Used for the Blackboard and Timeline memory systems.
*   **`jq`**: Used for JSON payload manipulation in bash scripts.

### MCP Servers
*   **`mcp-server-sqlite-npx`**: A custom Node.js wrapper for SQLite, providing `read_query`, `write_query`, `create_table`, etc. Used for both the Blackboard and the Timeline.
*   **`mcp-server-systemd`**: Provides systemd management capabilities (`change_unit_state`, `list_units`, `get_file`, `list_log`).
*   **`mcp-server-user-prompt`**: Allows the AI to prompt the user for confirmation before executing critical actions.

---

## 2. Configuration, Files, and Directories

### Directories
*   `~/.local/bin/`: Contains all executable wrapper scripts and MCP servers.
*   `~/hal_prompts/`: Contains all system prompts and persona definitions.
*   `~/.hal_memory/`: Contains the `timeline.db` (chat history).
*   `~/.config/systemd/user/`: Contains the `llama-server.service` definition.

### The Captain (HAL)
*   **Config**: `~/.hal.yml`
*   **Prompt**: `~/hal_prompts/system-prompt.md`
*   **Wrapper**: `~/.local/bin/hal`
*   **Role**: Remote model (Gemini 3.1 Pro). High-level strategy, complex debugging, and oversight.

### Firstmate (Coordinator Subagent)
*   **Config**: `~/.firsthal.yml`
*   **Prompt**: `~/hal_prompts/firstmate-prompt.md`
*   **Wrapper**: `~/.local/bin/firsthal`
*   **Role**: Local model (Gemma 27B). Autonomous coordinator. Reads the Blackboard, manages local state, and delegates heavy lifting to Matey.

### Matey (Worker Subagent)
*   **Config**: `~/.minihal.yml`
*   **Prompt**: `~/hal_prompts/matey-prompt.md`
*   **Wrapper**: `~/.local/bin/minihal`
*   **Role**: Local model (Gemma 27B). One-shot worker. Executes complex coding, log analysis, and text processing tasks delegated by Firstmate.

---

## 3. The Memory Genesis (SQLite Blackboard)

Initially, the system relied on reading and writing to Markdown files (`host_state.md`, `recent_history.md`). This caused massive context bloat and token waste because the AI had to read the entire file every time.

We replaced this with the **SQLite Blackboard Architecture**:
1.  **The Blackboard (`~/ship_state.db`)**: A centralized, ACID-compliant SQLite database containing three tables:
    *   `objectives`: Current mission goals.
    *   `alerts`: System warnings and hardware constraints.
    *   `action_log`: A running history of who did what.
2.  **The Timeline (`~/.hal_memory/timeline.db`)**: A separate database tracking the exact shell commands and AI responses for conversational context.

**How it works:**
Instead of reading a 500-line markdown file, Firstmate runs a targeted SQL query: `SELECT * FROM action_log ORDER BY timestamp DESC LIMIT 5;`. This uses almost zero tokens, provides instant context, and allows all three agents (Captain, Firstmate, Matey) to share the exact same "Ship Awareness" simultaneously without corrupting files.

---

## 4. System Tweaks & Optimizations (Layer by Layer)

<details>
<summary><b>🧠 Inference Engine Layer (llama.cpp)</b></summary>

*   **8-Bit KV Cache (`-ctk q8_0 -ctv q8_0`)**: By default, the context window is stored in 16-bit float. By quantizing the KV cache to 8-bit, we cut the memory footprint in half. This allowed the entire context window to fit inside the 8GB VRAM, preventing a massive 15GB system RAM spillover.
*   **Prompt Cache Capping (`--cache-ram 512`)**: `llama-server` defaults to an 8GB prompt cache. Because we inject the timeline into every prompt, this caused a 10GB memory leak. Capping it at 512MB stabilized system RAM perfectly.
*   **Cache Reuse (`--cache-reuse 256`)**: Optimizes how the smaller 512MB cache is chunked and reused, keeping response times fast.
*   **Systemd Daemonization**: Moved `llama-server` from being spawned by bash scripts to a persistent background `systemd` service. This prevents zombie processes and duplicate RAM allocations.
</details>

<details>
<summary><b>🤖 LLM / Reasoning Layer (Gemma 27B)</b></summary>

*   **The Reasoning Budget (`--reasoning-budget 128`)**: Gemma 4 is an "Instruct" model that uses an internal monologue (`<thought>`). Unbounded, it took 1m40s to answer simple questions. Disabled entirely, it lost its ability to write complex code. We set a "Goldilocks" budget of 128 tokens.
*   **The Anti-Hang Message (`--reasoning-budget-message "Thought process truncated. Proceeding to answer."`)**: When the 128-token budget runs out, the model used to panic and hang for 5 minutes. Injecting this exact string forces the model to gracefully exit its monologue and output the final answer immediately.
</details>

<details>
<summary><b>🕵️ Agents Layer (Kit / MCP)</b></summary>

*   **Native Subagent Delegation**: Firstmate is strictly forbidden from writing code. It uses Kit's native `subagent` tool (configured in `.firsthal.yml` under `customModels`) to spawn Matey for heavy lifting.
*   **Single-Shot Bash Injection**: When calling Firstmate from the CLI (non-interactive), tool calls add ~10 seconds of overhead. We optimized the `firsthal` wrapper script to use `sqlite3` bash commands to fetch the Blackboard state and inject it directly into the prompt, bypassing the MCP tool overhead entirely and dropping response times to ~25 seconds.
</details>

<details>
<summary><b>📝 Prompts Layer</b></summary>

*   **Strict Role Enforcement**: Firstmate's prompt explicitly states: *"You are a Coordinator, NOT a worker. You must NEVER write scripts... If you generate code directly in your response, you fail your core directive."*
*   **One-Shot Worker**: Matey's prompt strips away all conversational pleasantries and long-term memory instructions, forcing it to act as a pure, stateless function.
</details>

---

## 5. Fresh Install Guide

Follow these steps to deploy this architecture on a freshly installed system containing only the `kit` binary (named `hal-bin`).

### Step 1: Directory Setup
```bash
mkdir -p ~/.local/bin
mkdir -p ~/hal_prompts/personas
mkdir -p ~/.hal_memory/sessions
mkdir -p ~/.config/systemd/user
mkdir -p ~/minihal_temp
```

### Step 2: Copy Files
1. Copy all `.yml` files (`.hal.yml`, `.firsthal.yml`, `.minihal.yml`) from `configs/` to `~/`.
2. Copy all wrapper scripts (`hal`, `firsthal`, `minihal`, `delegate_to_matey`, `mcp-server-sqlite-npx`) from `bin/` to `~/.local/bin/` and make them executable (`chmod +x ~/.local/bin/*`).
3. Copy all markdown prompts from `prompts/` to `~/hal_prompts/`.
4. Copy `llama-server.service` from `systemd/` to `~/.config/systemd/user/`.

### Step 3: Initialize the SQLite Memory
```bash
# Initialize the Blackboard
sqlite3 ~/ship_state.db < memory_schema/ship_state_schema.sql

# Initialize the Timeline
sqlite3 ~/.hal_memory/timeline.db < memory_schema/timeline_schema.sql

# Seed initial hardware constraints
sqlite3 ~/ship_state.db "INSERT INTO alerts (alert_text, severity) VALUES ('Hardware constraints: 8GB VRAM limit. Gemma 27B model split between GPU/CPU. 8-bit KV cache active to save RAM.', 'INFO');"
```

### Step 4: Start the Inference Engine
```bash
systemctl --user daemon-reload
systemctl --user enable --now llama-server.service
```
*Wait for the model to load into memory (check `systemctl --user status llama-server`).*

### Step 5: Verify the Installation
```bash
# Test Firstmate (Should respond in ~30s)
firsthal "who are you?"

# Test Matey (Should respond in ~60s with code)
minihal "Write a python script that prints hello world."
```

You are now ready to sail!
