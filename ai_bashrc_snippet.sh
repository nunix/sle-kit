# ==========================================
# AI Crew Integration (Captain, Firstmate, Matey)
# ==========================================

# 1. Aliases for the AI Crew
alias captain="~/.local/bin/captain"
alias firstmate="~/.local/bin/firstmate"
alias matey="~/.local/bin/matey"

# 2. Timeline Hook (Logs shell commands to the AI's memory)
__kit_postgres_hook() {
    # Only log if CLEAN_CMD is set and not empty (requires a precmd setup to capture commands)
    if [ -n "$CLEAN_CMD" ]; then
        psql postgresql://nunix:nunix@localhost/ship_state -c "INSERT INTO Timeline (session_id, actor, event_type, content) VALUES ((SELECT session_id FROM ActiveSession WHERE id=1), 'User', 'Shell_Command', '${CLEAN_CMD//\'/\'\'}');" >/dev/null 2>&1
    fi
}

# Attach the hook to bash DEBUG trap
trap __kit_postgres_hook DEBUG
