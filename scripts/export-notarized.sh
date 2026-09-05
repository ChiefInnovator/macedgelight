#!/bin/bash
# Xcode upload returns before Apple finishes processing the archive.
set -euo pipefail
archive_path="$1"
export_path="$2"
mkdir -p "$(dirname "$export_path")"
staging_path=$(mktemp -d "${export_path}.XXXXXX")
log_path=$(mktemp -t macedgelight-notarization)
trap 'rm -f "$log_path"' EXIT
for attempt in {1..40}; do
    if xcodebuild -exportNotarizedApp -archivePath "$archive_path" -exportPath "$staging_path" >"$log_path" 2>&1; then
        cat "$log_path"
        if [[ -e "$export_path" ]]; then
            mv "$export_path" "${staging_path}.previous"
        fi
        mv "$staging_path" "$export_path"
        exit 0
    fi
    cat "$log_path"
    if ! grep -Fq 'is processing and not ready for distribution' "$log_path"; then
        exit 1
    fi
    if (( attempt < 40 )); then
        echo "Apple is processing notarization; checking again in 15 seconds ($attempt/40)."
        sleep 15
    fi
done
echo "Apple is still processing. Retry: bash scripts/export-notarized.sh \"$archive_path\" \"$export_path\"" >&2
exit 1
