#!/bin/bash

# Constants
NAME="repo-sign-rpms"
REPO_KEY='@org_name@ Package Signing Key'

# Bail on error
set -e

# Usage message
usage()
{
    echo "Usage: ${NAME} file.rpm ..." 1>&2
}

# Parse flags passed in on the command line
while [ ${#} -gt 0 ]; do
    case "$1" in
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
    0)
        usage
        exit 1
        ;;
    *)
        ;;
esac

# Verify signing key exists
if ! gpg2 --list-keys "${REPO_KEY}" 2>/dev/null; then
    echo "${REPO_DIR}: RPM signing key \"${REPO_KEY}\" not found" 1>&2
    exit 1
fi

# Validate files
for RPM in "$@"; do
    if ! [ -f "${RPM}" ] || ! file "${RPM}" | grep -qw RPM 2>/dev/null; then
        echo "${RPM}: not a valid RPM file" 1>&2
        exit 1
    fi
done

# Sign RPM files
rpm --define "_gpg_name ${REPO_KEY}" --addsign "$@"
