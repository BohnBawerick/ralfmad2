#!/bin/bash
# Claude Code Router driver for Ralph
# Provides platform-specific CLI invocation logic

# Driver identification
driver_name() {
    echo "ccr"
}

driver_display_name() {
    echo "Claude Code Router"
}

driver_cli_binary() {
    echo "ccr"
}

driver_min_version() {
    echo "1.0.0"
}

# Check if the CLI binary is available
driver_check_available() {
    command -v "$(driver_cli_binary)" &>/dev/null
}

# Valid tool patterns for --allowedTools validation
# Sets the global VALID_TOOL_PATTERNS array
driver_valid_tools() {
    VALID_TOOL_PATTERNS=(
        "Write"
        "Read"
        "Edit"
        "MultiEdit"
        "Glob"
        "Grep"
        "Task"
        "TodoWrite"
        "WebFetch"
        "WebSearch"
        "AskUserQuestion"
        "EnterPlanMode"
        "ExitPlanMode"
        "Bash"
        "Bash(git *)"
        "Bash(npm *)"
        "Bash(bats *)"
        "Bash(python *)"
        "Bash(node *)"
        "NotebookEdit"
    )
}

driver_supports_tool_allowlist() {
    return 0
}

driver_permission_denial_help() {
    echo "  1. Edit \$RALPHRC_FILE and keep CLAUDE_PERMISSION_MODE=bypassPermissions for unattended loops"
    echo "  2. If it was denied on an interactive approval step, ALLOWED_TOOLS will not fix it"
    echo "  3. If it was denied on a normal tool, update ALLOWED_TOOLS to include the required tools"
    echo "  4. Common ALLOWED_TOOLS patterns:"
    echo "     - Bash                - All shell commands"
    echo "     - Bash(node *)        - All Node.js commands"
    echo "     - Bash(npm *)         - All npm commands"
    echo "     - Bash(pnpm *)        - All pnpm commands"
    echo "     - AskUserQuestion     - Allow interactive clarification when you want pauses"
    echo ""
    echo "After updating \$RALPHRC_FILE:"
    echo "  bash .ralph/ralph_loop.sh --reset-session  # Clear stale session state"
    echo "  bmalph run                                 # Restart the loop"
}

# Build the CLI command arguments
# Populates global CLAUDE_CMD_ARGS array
driver_build_command() {
    local prompt_file=$1
    local loop_context=$2
    local session_id=$3
    local resolved_permission_mode="${CLAUDE_PERMISSION_MODE:-bypassPermissions}"

    CLAUDE_CMD_ARGS=("$(driver_cli_binary)")

    if [[ ! -f "$prompt_file" ]]; then
        echo "ERROR: Prompt file not found: $prompt_file" >&2
        return 1
    fi

    # Output format
    if [[ "$CLAUDE_OUTPUT_FORMAT" == "json" ]]; then
        CLAUDE_CMD_ARGS+=("--output-format" "json")
    fi

    CLAUDE_CMD_ARGS+=("--permission-mode" "$resolved_permission_mode")

    # Allowed tools
    if [[ -n "$CLAUDE_ALLOWED_TOOLS" ]]; then
        CLAUDE_CMD_ARGS+=("--allowedTools")
        local IFS=','
        read -ra tools_array <<< "$CLAUDE_ALLOWED_TOOLS"
        for tool in "\${tools_array[@]}"; do
            tool=$(echo "$tool" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -n "$tool" ]]; then
                CLAUDE_CMD_ARGS+=("$tool")
            fi
        done
    fi

    if [[ "$CLAUDE_USE_CONTINUE" == "true" && -n "$session_id" ]]; then
        CLAUDE_CMD_ARGS+=("--resume" "$session_id")
    fi

    if [[ -n "$loop_context" ]]; then
        CLAUDE_CMD_ARGS+=("--append-system-prompt" "$loop_context")
    fi

    local prompt_content
    prompt_content=$(cat "$prompt_file")
    CLAUDE_CMD_ARGS+=("-p" "$prompt_content")
}

driver_supports_sessions() {
    return 0  # true
}

driver_supports_live_output() {
    return 0  # true
}

driver_prepare_live_command() {
    LIVE_CMD_ARGS=()
    local skip_next=false

    for arg in "\${CLAUDE_CMD_ARGS[@]}"; do
        if [[ "$skip_next" == "true" ]]; then
            LIVE_CMD_ARGS+=("stream-json")
            skip_next=false
        elif [[ "$arg" == "--output-format" ]]; then
            LIVE_CMD_ARGS+=("$arg")
            skip_next=true
        else
            LIVE_CMD_ARGS+=("$arg")
        fi
    done

    if [[ "$skip_next" == "true" ]]; then
        return 1
    fi

    LIVE_CMD_ARGS+=("--verbose" "--include-partial-messages")
}

driver_stream_filter() {
    echo '
        if .type == "stream_event" then
            if .event.type == "content_block_delta" and .event.delta.type == "text_delta" then
                .event.delta.text
            elif .event.type == "content_block_start" and .event.content_block.type == "tool_use" then
                "\n\n⚡ [" + .event.content_block.name + "]\n"
            elif .event.type == "content_block_stop" then
                "\n"
            else
                empty
            end
        else
            empty
        end'
}
