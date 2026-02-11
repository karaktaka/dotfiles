#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract values from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model_name=$(echo "$input" | jq -r '.model.display_name')
output_style=$(echo "$input" | jq -r '.output_style.name')

# Get AWS Profile
aws_profile="${AWS_PROFILE:-}"
aws_info=""
if [ -n "$aws_profile" ]; then
    aws_info=$(printf ' \033[33maws:%s\033[0m' "$aws_profile")
fi

# Get Kubernetes context (extract cluster name only)
k8s_info=""
k8s_context=$(kubectl config current-context 2>/dev/null)
if [ -n "$k8s_context" ]; then
    # Extract just the cluster name from ARN or path
    # Handles formats like: arn:aws:eks:region:account:cluster/name or simple names
    cluster_name=$(echo "$k8s_context" | sed -E 's#.*/##' | sed -E 's#.*cluster/##')
    if [ -n "$cluster_name" ]; then
        k8s_info=$(printf ' \033[36mk8s:%s\033[0m' "$cluster_name")
    fi
fi

# Determine directory display name
dir_name="$cwd"
git_info=""

if cd "$cwd" 2>/dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
    # Get repo name
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$repo_root" ]; then
        dir_name=$(basename "$repo_root")
    fi

    # Get branch info
    branch=$(git -c core.useBuiltinFSMonitor=false -c core.fsmonitor=false branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
        # Check if repo is dirty (skip optional locks to avoid blocking)
        if ! git -c core.useBuiltinFSMonitor=false -c core.fsmonitor=false diff --quiet 2>/dev/null || ! git -c core.useBuiltinFSMonitor=false -c core.fsmonitor=false diff --cached --quiet 2>/dev/null; then
            git_info=$(printf ' \033[32m%s\033[31m*\033[0m' "$branch")
        else
            git_info=$(printf ' \033[32m%s\033[0m' "$branch")
        fi
    fi
fi

# Build status line
# Format: [dir/repo] [branch*] [aws:profile] [k8s:cluster] | model [style]
printf '\033[37m%s\033[0m%s%s%s \033[34m|\033[0m \033[1;34m%s\033[0m \033[90m[%s]\033[0m' \
    "$dir_name" \
    "$git_info" \
    "$aws_info" \
    "$k8s_info" \
    "$model_name" \
    "$output_style"
