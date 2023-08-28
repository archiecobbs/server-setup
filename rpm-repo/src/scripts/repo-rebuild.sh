#!/bin/bash

# Constants
NAME="repo-rebuild"
REPO_BASE='@repo_dir@'
REPO_KEY='@org_name@ Package Signing Key'

# Bail on error
set -e

# Usage message
usage()
{
    echo "Usage: ${NAME} [-f] repodir" 1>&2
    echo "Options:" 1>&2
    echo "    -f        Force build even if repodir is unrecognized" 1>&2
    echo "    -u        Just update instead of rebuilding from scratch" 1>&2
}

# Parse flags passed in on the command line
REPO_DIR=""
FORCE="false"
UPDATE="false"
while [ ${#} -gt 0 ]; do
    case "$1" in
        -f)
            FORCE="true"
            shift
            ;;
        -u)
            UPDATE="true"
            shift
            ;;
        -h|--help)
            usage
            exit
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
done
case "${#}" in
    1)
        REPO_DIR="$1"
        ;;
    *)
        usage
        exit 1
        ;;
esac

# Validate REPO_DIR
REPO_DIR=`readlink -f "${REPO_DIR}"`
if [ "${FORCE}" != 'true' ] && [ `dirname ${REPO_DIR}` != "${REPO_BASE}" ]; then
    echo "${REPO_DIR}: not a known RPM repository" 1>&2
    exit 1
fi

# Verify signing key exists
if ! gpg2 --list-keys "${REPO_KEY}" 2>/dev/null; then
    echo "${REPO_DIR}: RPM signing key \"${REPO_KEY}\" not found" 1>&2
    exit 1
fi

# Set umask
umask 002

# Reset cache if not just updating
CACHE_DIR="${REPO_DIR}/cache"
if [ "${UPDATE}" != 'true' ]; then
    find "${CACHE_DIR}" -type f -print0 | xargs -0 rm -f
fi

# Regenerate/update repository
if [ "${UPDATE}" = 'true' ]; then
    createrepo --cachedir "${CACHE_DIR}" --update "${REPO_DIR}"
else
    createrepo --cachedir "${CACHE_DIR}" "${REPO_DIR}"
fi

# Sign repo data
rm -f "${REPO_DIR}"/repodata/repomd.xml.asc
gpg2 -sabq --default-key "${REPO_KEY}" "${REPO_DIR}"/repodata/repomd.xml
