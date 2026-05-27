#!/usr/bin/env bash

# Resolve script directory: ACTION_DIR is set in native mode, falls back to / for Docker
script_dir="${ACTION_DIR:-}"

# Check required env variables
flag=0
mode="WEBHOOK"
if [[ -z "$SLACK_WEBHOOK" ]]; then
    flag=1
    missing_secret="SLACK_WEBHOOK"
    if command -v vault &>/dev/null; then
        if [[ -n "$VAULT_ADDR" ]] && [[ -n "$VAULT_TOKEN" ]]; then
            flag=0
            echo -e "[\e[0;33mWARNING\e[0m] Both \`VAULT_ADDR\` and \`VAULT_TOKEN\` are provided. Using Vault for secrets. This feature is deprecated and will be removed in future versions. Please provide the credentials directly.\n"
        fi
    elif [[ -n "$VAULT_ADDR" ]] || [[ -n "$VAULT_TOKEN" ]]; then
        echo "::warning::Vault CLI not available. Vault support is deprecated and not available in non-Docker mode. Please provide SLACK_WEBHOOK directly."
    fi
    if [[ -n "$VAULT_ADDR" ]] || [[ -n "$VAULT_TOKEN" ]]; then
        missing_secret="VAULT_ADDR and/or VAULT_TOKEN"
    fi
fi

if [[ "$flag" -eq 1 ]] && [[ -n "$SLACK_TOKEN" || -n "$SLACK_CHANNEL" ]] ; then
    # Basically, if both SLACK_TOKEN and SLACK_CHANNEL are provided, then it's a token mode
    flag=0
    mode="TOKEN"
fi

if [[ "$flag" -eq 1 ]]; then
    echo -e "[\e[0;31mERROR\e[0m] Secret \`$missing_secret\` is missing. Alternatively, a pair of \`SLACK_TOKEN\` and \`SLACK_CHANNEL\` can be provided. Please add it to this action for proper execution.\nRefer https://github.com/rtCamp/action-slack-notify for more information.\n"
    exit 1
fi

export MSG_MODE="$mode"

if [[ -n "$SLACK_FILE_UPLOAD" ]]; then
  if [[ -z "$SLACK_TOKEN" ]]; then
    echo -e "[\e[0;31mERROR\e[0m] Secret \`SLACK_TOKEN\` is missing and a file upload is specified. File Uploads require an application token to be present.\n"
    exit 1
  fi
  if [[ -z "$SLACK_CHANNEL" ]]; then
    echo -e "[\e[0;31mERROR\e[0m] Secret \`SLACK_CHANNEL\` is missing and a file upload is specified. File Uploads require a channel to be specified.\n"
    exit 1
  fi
fi

# custom path for files to override default files
custom_path="$GITHUB_WORKSPACE/.github/slack"
if [[ -z "$script_dir" ]]; then
    main_script="/main.sh"
else
    main_script="$script_dir/main.sh"
fi

if [[ -d "$custom_path" ]]; then
    target_dir="${script_dir:-/}"
    if command -v rsync &>/dev/null; then
        rsync -av "$custom_path/" "$target_dir/"
    else
        cp -rf "$custom_path"/. "$target_dir/"
    fi
    chmod +x "$target_dir"/*.sh 2>/dev/null || true
fi

bash "$main_script"
