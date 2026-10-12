#!/bin/bash
set -euo pipefail

# Run as the final archive build phase; ordinary development builds stay offline.
if [[ "${CONFIGURATION:-}" != "Release" ]]; then
    echo "info: PostHog symbol upload is only required for Release archives."
    exit 0
fi

# Pin the destination independently of any other project's CLI login defaults.
# Supply the official CLI's credentials from the build environment or its
# POSTHOG_CLI_DOTENV_FILE; never from app Info.plist or a checked-in xcconfig.
export POSTHOG_CLI_HOST="https://eu.posthog.com"
export POSTHOG_CLI_PROJECT_ID="261844"

# Xcode's standard SPM checkout location, with an override for CI builds that
# use -clonedSourcePackagesDirPath.
if [[ -n "${POSTHOG_SPM_CHECKOUT:-}" ]]; then
    posthog_checkout="$POSTHOG_SPM_CHECKOUT"
else
    : "${BUILD_DIR:?BUILD_DIR is required}"
    posthog_checkout="${BUILD_DIR%/Build/*}/SourcePackages/checkouts/posthog-ios"
fi
posthog_upload_script="$posthog_checkout/build-tools/upload-symbols.sh"
if [[ ! -f "$posthog_upload_script" ]]; then
    echo "error: PostHog SDK upload script not found; set POSTHOG_SPM_CHECKOUT for a custom package checkout."
    exit 1
fi

# Delegate dSYM discovery, release binding and upload to the official SDK tool.
# Its failure must fail the archive rather than silently losing symbolication.
exec /bin/bash "$posthog_upload_script"
