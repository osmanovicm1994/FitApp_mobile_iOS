#!/bin/sh
set -eu

VERSION="${1:?Usage: install-shared-release.sh <shared-version>}"
case "$VERSION" in
  *[!0-9.]* | "") echo "Invalid shared version: $VERSION" >&2; exit 2 ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP_ROOT=$(dirname "$SCRIPT_DIR")
WORKSPACE_ROOT=$(dirname "$APP_ROOT")
PROJECT_FILE="$APP_ROOT/FitApp.xcodeproj/project.pbxproj"
PACKAGE_NAME="FitAppSharedModuleArtifacts-$VERSION"
ARCHIVE_NAME="$PACKAGE_NAME.zip"
SHARED_ROOT="$WORKSPACE_ROOT/FitApp-Shared"
DESTINATION="$SHARED_ROOT/artifacts/$PACKAGE_NAME"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf -- "$TEMP_DIR"' EXIT HUP INT TERM

if [ -e "$DESTINATION" ]; then
  echo "Shared package already exists at $DESTINATION" >&2
  exit 1
fi

gh release download "shared-v$VERSION" \
  --repo osmanovicm1994/FitApp-Shared \
  --pattern "$ARCHIVE_NAME" \
  --dir "$TEMP_DIR"
mkdir -p "$SHARED_ROOT/artifacts"
ditto -x -k "$TEMP_DIR/$ARCHIVE_NAME" "$SHARED_ROOT/artifacts"
test -f "$DESTINATION/FITAPP_SHARED_VERSION.txt"
test "$(cat "$DESTINATION/FITAPP_SHARED_VERSION.txt")" = "$VERSION"
python3 - "$PROJECT_FILE" "$PACKAGE_NAME" <<'PY'
from pathlib import Path
import re
import sys

project = Path(sys.argv[1])
package_name = sys.argv[2]
source = project.read_text()
updated, count = re.subn(r"FitAppSharedModuleArtifacts-\d+\.\d+\.\d+", package_name, source)
if count == 0:
    raise SystemExit("Could not find the versioned FitApp Shared package reference in project.pbxproj")
project.write_text(updated)
PY
echo "Installed FitApp Shared $VERSION"
