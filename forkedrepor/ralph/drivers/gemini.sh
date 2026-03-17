#!/bin/bash
# Gemini driver for Ralph
# Provides platform-specific CLI invocation logic

# Driver identification
driver_name() {
    echo "gemini"
}

driver_display_name() {
    echo "Gemini CLI"
}

driver_cli_binary() {
    echo "gemini"
}

driver_min_version() {
    echo "1.0.0"
}

# Check if the CLI binary is available
driver_check_available() {
    command -v "$(driver_cli_binary)" &>/dev/null
}

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
    echo "  1. Check Gemini CLI settings for terminal applications."
}

# Build the CLI command arguments
# Populates global CLAUDE_CMD_ARGS array
driver_build_command() {
    local prompt_file=$1
    local loop_context=$2
    local session_id=$3

    CLAUDE_CMD_ARGS=("$(driver_cli_binary)")

    if [[ ! -f "$prompt_file" ]]; then
        echo "ERROR: Prompt file not found: $prompt_file" >&2
        return 1
    fi

    # Appending simple prompt file content as last argument
    local prompt_content
    prompt_content=$(cat "$prompt_file")
    CLAUDE_CMD_ARGS+=("$prompt_content")
}

driver_supports_sessions() {
    return 0
}

driver_supports_live_output() {
    return 0
}

driver_prepare_live_command() {
    LIVE_CMD_ARGS=("\${CLAUDE_CMD_ARGS[@]}")
}

driver_stream_filter() {
    # Assuming text format, not json
    echo '.'
}
