#!/bin/bash
cd "$(dirname "$0")"
##############################################################################
# get-and-build-spock.sh
# Automates the process of generating a source tarball from a specific branch
# of the Spock repository, and building binaries for multiple PostgreSQL versions.
# Version is loaded from versions.sh 
##############################################################################

set -e
set -u

# ----------- BASE PATHS AND ENVIRONMENT CHECKS -----------------------------

# Ensure environment variables are set otherwise exit.
BLD="${BLD:-}"
SOURCE="${SOURCE:-}"
IN="${IN:-}"

if [[ -z "${BLD}" || -z "${SOURCE}" || -z "${IN}" ]]; then
  echo "[ERROR] BLD, SOURCE, and IN environment variables must be set before running this script."
  exit 2
fi

# ----------- ARGUMENT PARSING ----------------------------------------------

print_usage() {
  echo "Usage: $0 -b <branch> -c <componentname> [-p <pgvers>]"
  echo "  -b   git branch in the spock repo to use (required)"
  echo "  -c   component name (e.g., spock50) (required)"
  echo "  -p   Comma-separated PG major versions to build against (optional, default: 15,16,17)"
  echo ""
  echo "Example:"
  echo "  $0 -b main -c spock50 -p 15,16,17"
  exit 2
}

LABEL=""
PGVERS="15,16,17"

# Parse input arguments, branch and component are mandatory
while getopts "b:c:p:" opt; do
  case $opt in
    b) BRANCH="$OPTARG" ;;
    c) COMPONENT="$OPTARG" ;;
    p) PGVERS="$OPTARG" ;;
    *) print_usage ;;
  esac
done

if [[ -z "${BRANCH:-}" || -z "${COMPONENT:-}" ]]; then
  echo "[ERROR] -b and -c are required."
  print_usage
fi

if [[ "${COMPONENT,,}" != *spock* ]]; then
  echo "[ERROR] The component name must contain 'spock'. You entered: $COMPONENT"
  exit 2
fi

IFS=',' read -ra PGARRAY <<< "$PGVERS"

# Set commonly used paths based on component
COMPONENT_SOURCE_DIR="$SOURCE"
COMPONENT_BIN_DIR="$IN/postgres/$COMPONENT"

# ----------- LOAD VERSION INFO ---------------------------------------------

# Source versions.sh and extract the version value for the component
source "$BLD/versions.sh"
VAR="${COMPONENT}V"
VERSIONLABEL="${!VAR}"  # Assigns value e.g. 5.0.0devel1 from the spock50V=5.0.0devel1
if [[ -z "${VERSIONLABEL:-}" ]]; then
  echo "[ERROR] No version found for $COMPONENT in $BLD/versions.sh"
  exit 2
fi

echo "[INFO] get-and-build-spock.sh starting with:"
echo "  Branch:        $BRANCH"
echo "  Component:     $COMPONENT"
echo "  VersionLabel:  $VERSIONLABEL"
echo "  PG Versions:   ${PGARRAY[*]}"
echo "  BLD:           $BLD"
echo "  SOURCE:        $SOURCE"
echo "  IN:            $IN"
echo ""

# ----------- FUNCTIONS -----------------------------------------------------

# Check if the spock repo is present , otherwise exit
# The spock repo is a requirement for pgbin-builds, so it should pre-exist. 
# However, the function can be enhanced to clone spock in $BLD if it doesn't exist 
check_spock_repo() {
  echo "[INFO] Checking for Spock repository in $BLD/spock ..."
  if [[ ! -d "$BLD/spock" ]]; then
    echo "[ERROR] Spock repository ($BLD/spock) not found. Aborting."
    exit 2
  fi
}

# Remove any previous source tarballs for the component (default or from previous runs)
cleanup_sources() {
  echo "[INFO] Cleaning up old source tarballs for $COMPONENT in $COMPONENT_SOURCE_DIR ..."
  rm -fv "$COMPONENT_SOURCE_DIR/$COMPONENT"-*.tar.gz || true
}

# Create a source tarball from the specified spock branch, 
# using the component version from versions.sh
create_source_tarball() {
  cd "$BLD/spock"
  echo "[INFO] Fetching latest branch refs from origin ..."
  git fetch origin

  # Print the latest commit hash and one-liner message from commit log
  LATEST_COMMIT_MSG=$(git log -1 --pretty=oneline origin/"$BRANCH")
  echo "[INFO] Latest commit on $BRANCH: $LATEST_COMMIT_MSG"

  TAR_NAME="${COMPONENT}-${VERSIONLABEL}.tar.gz"
  echo "[INFO] Creating source tarball: $TAR_NAME from origin/$BRANCH ..."
  # create a git source archive tar.gz for the given branch 
  git archive --format=tar.gz --prefix="${COMPONENT}-${VERSIONLABEL}/" -o "$COMPONENT_SOURCE_DIR/$TAR_NAME" "origin/$BRANCH"
  echo "[INFO] Source Tarball created at $COMPONENT_SOURCE_DIR/$TAR_NAME"
}

# Clean up all previous binary tarballs for this component-pgV prior to building new
cleanup_binaries() {
  PGVER="$1"
  echo "[INFO] Cleaning up old binaries for $COMPONENT/PG$PGVER in $COMPONENT_BIN_DIR ..."
  rm -fv "$COMPONENT_BIN_DIR/$COMPONENT-pg$PGVER-"*.tgz || true
}

# Function to build spock against a given pg version
build_for_pgver() {
  PGVER="$1"
  echo "[INFO] Building $COMPONENT for PostgreSQL $PGVER ..."
  cd "$BLD"
  # If build fails, script will exit due to set -e
  if ! ./build-all-components.sh "$COMPONENT" "$PGVER" --copy-bin; then
    echo "[ERROR] Build failed for $COMPONENT PG$PGVER! Exiting."
    exit 2
  fi
  echo "[INFO] Build for $COMPONENT (PG$PGVER) complete."
}

# Print a summary of what was built
print_summary() {
  echo ""
  echo "===================================================="
  echo "[SUMMARY] Build complete!"

  echo "  Source tarball(s):"
  ls -lh "$COMPONENT_SOURCE_DIR"/${COMPONENT}-*.tar.gz

  echo ""
  echo "  Binary package(s):"
  ls -lh "$COMPONENT_BIN_DIR"/*.tgz

  echo "===================================================="
}


# ----------- MAIN ----------------------------------------------------

#check for presence of spock repo cloned inside $BLD
check_spock_repo
#cleanup any older spock source tarball for the given spock version
cleanup_sources
#create new source tarball from the specified branch
create_source_tarball
#build spock against the given pg version
for PGVER in "${PGARRAY[@]}"; do
  cleanup_binaries "$PGVER"
  build_for_pgver "$PGVER"
  sleep 3
done

print_summary

echo "[INFO] get-and-build-spock.sh finished successfully."
