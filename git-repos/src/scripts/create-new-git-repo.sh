#!/bin/bash

# Constants
NAME="create-new-git-repo"
DEFAULT_PARENT_DIR='@repo_dir@'
DEFAULT_EMAIL_FROM='noreply@@org_domain@'
DEFAULT_EMAIL_PREFIX='GIT'
DEFAULT_EMAIL_SCRIPT='@email_script@'

# Bail on error
set -e

# Usage message
usage()
{
    echo "Usage: ${NAME} [options] --group group repo-name" 1>&2
    echo "Options:" 1>&2
    echo "    -d,--dir dir              Set parent directory (default \"${DEFAULT_PARENT_DIR}\")" 1>&2
    echo "    -g,--group group          Specify UNIX group allowing access to repository (required)" 1>&2
    echo "    --email address           Email to the given email address when a new push is received" 1>&2
    echo "    --email-from address      Set email from address (default \"${DEFAULT_EMAIL_FROM}\")" 1>&2
    echo "    --email-prefix prefix     Set email subject line prefix (default \"${DEFAULT_EMAIL_PREFIX}\")" 1>&2
    echo "    --email-script script     Set alternate email post-receive hook (default \"${DEFAULT_EMAIL_SCRIPT}\")" 1>&2
    echo "    -n,--no-git-suffix        Don't append \".git\" suffix to the new repo directory" 1>&2
    echo "    -h,--help                 Show this help message" 1>&2
}

# Parse flags passed in on the command line
PARENT_DIR="${DEFAULT_PARENT_DIR}"
EMAIL_DEST=""
EMAIL_FROM="${DEFAULT_EMAIL_FROM}"
EMAIL_PREFIX="${DEFAULT_EMAIL_PREFIX}"
EMAIL_SCRIPT="${DEFAULT_EMAIL_SCRIPT}"
UNIX_GROUP=""
NO_GIT_SUFFIX="false"
EMAIL_CONFIGURED="false"
while [ ${#} -gt 0 ]; do
    case "$1" in
        -d|--dir)
            shift
            PARENT_DIR="${1}"
            shift
            ;;
        --email)
            shift
            EMAIL_DEST="${1}"
            EMAIL_CONFIGURED="true"
            shift
            ;;
        --email-from)
            shift
            EMAIL_FROM="${1}"
            EMAIL_CONFIGURED="true"
            shift
            ;;
        --email-prefix)
            shift
            EMAIL_PREFIX="${1}"
            EMAIL_CONFIGURED="true"
            shift
            ;;
        --email-script)
            shift
            EMAIL_SCRIPT="${1}"
            EMAIL_CONFIGURED="true"
            shift
            ;;
        -g|--group)
            shift
            UNIX_GROUP="${1}"
            shift
            ;;
        -n|--no-git-suffix)
            NO_GIT_SUFFIX="true"
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
        REPO_NAME="${1}"
        ;;
    *)
        usage
        exit 1
        ;;
esac

# Verify group
if [ -z "${UNIX_GROUP}" ]; then
    echo "${NAME}: no UNIX group specified; try \"--group\"" 1>&2
    usage
    exit 1
fi
if ! grep -qE "^${UNIX_GROUP}:" /etc/group; then
    echo "${NAME}: UNIX group \"${UNIX_GROUP}\" does not exist" 1>&2
    exit 1
fi

# Email flags require "--email"
if [ "${EMAIL_CONFIGURED}" = 'true' ]; then
    if [ -z "${EMAIL_DEST}" ]; then
        echo "${NAME}: no email destination configured; try \"--email\"" 1>&2
        usage
        exit 1
    fi
    if ! [ -f "${EMAIL_SCRIPT}" ]; then
        echo "${NAME}: email post-receive hook \"${EMAIL_SCRIPT}\" not found" 1>&2
        exit 1
    fi
fi

# Sanity check repo directory
if ! [ -d "${PARENT_DIR}" ]; then
    echo "${NAME}: invalid/unknown parent directory \"${PARENT_DIR}\"" 1>&2
    exit 1
fi
REPO_DIR="${PARENT_DIR}/${REPO_NAME}"
if [ "${NO_GIT_SUFFIX}" != 'true' ] && ! echo "${REPO_DIR}" | grep -qE '\.git$'; then
    REPO_DIR="${REPO_DIR}.git"
fi
if [ -e "${REPO_DIR}" ]; then
    echo "${NAME}: repository directory \"${REPO_DIR}\" already exists" 1>&2
    exit 1
fi

# Create repository
echo "${NAME}: creating repository \"${REPO_DIR}\"" 1>&2
git init --bare --shared=0660 "${REPO_DIR}"

# Set permissions
echo "${NAME}: setting directory permissions" 1>&2
chgrp -R "${UNIX_GROUP}" "${REPO_DIR}"
chmod -R g+rw "${REPO_DIR}"
find "${REPO_DIR}" -type d -print0 | xargs -0 chmod g+s

# Set up email notifications
if [ "${EMAIL_CONFIGURED}" = 'true' ]; then
    echo "${NAME}: configuring email notifications to \"${EMAIL_DEST}\"" 1>&2
    install -m 755 "${EMAIL_SCRIPT}" "${REPO_DIR}"/hooks/post-receive
    printf '\n[multimailhook]\n\trepoName = %s\n\tmailingList = %s\n\tcommitEmailFormat = html\n\tfrom = %s\n' \
        "${EMAIL_PREFIX}" "${EMAIL_DEST}" "${EMAIL_FROM}" \
        >> "${REPO_DIR}"/config
fi

# Done
echo "${NAME}: repo created at file://${REPO_DIR}" 1>&2
