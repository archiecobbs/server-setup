#!/bin/sh

#
# This file contains some helpful functions for RPM scripts
# To use it, you must require the "%{org_id}-rpm-scripts" RPM
# and then include the following line in your RPM scriptlet(s):
#
#   . %{_datadir}/%{org_id}-rpm-scripts/rpm-scripts '%{name}' '%{version}' '%{release}'
#

# Set environment variables needed by these scripts
set_rpm_variables()
{
    RPM_PACKAGE_NAME="$1"
    RPM_PACKAGE_VERSION="$2"
    RPM_PACKAGE_RELEASE="$3"
}

#
# Function that transforms an XML file using xsltproc(1).
#
# Arguments:
#   1. Target XML file (required)
#   2. XSLT transform (required; only version 1.0 supported)
#   3. Any additional flag(s) to xsltproc(1) (optional)
#
xml_patch_file()
{
    # Get target and XSLT file
    FILE="${1}"
    shift
    if ! [ -f "${FILE}" ]; then
        echo "xml_patch_file: target file \"${FILE}\" not found" 2>&1
        return
    fi
    XSLT="${1}"
    shift
    if ! [ -f "${XSLT}" ]; then
        echo "xml_patch_file: transform file \"${XSLT}\" not found" 2>&1
        return
    fi

    # Apply transform
    if ! xsltproc --nomkdir --nonet --nowrite ${1+"$@"} "${XSLT}" "${FILE}" > "${FILE}".new; then
        echo "xml_patch_file: error patching `basename ${FILE}`; patch not applied!" 1>&2
    elif ! diff -q "${FILE}" "${FILE}".new >/dev/null; then
        cat "${FILE}".new > "${FILE}"
    fi
    rm -f "${FILE}".new
}

# Function that patches a file using sed(1).
# First argument is filename, subsequent arguments are passed to sed(1).
sed_patch_file()
{
    FILE="${1}"
    shift
    if ! sed ${1+"$@"} < "${FILE}" > "${FILE}".new; then
        echo "sed_patch_file: error patching `basename ${FILE}`; patch not applied!" 1>&2
    elif ! diff -q "${FILE}" "${FILE}".new >/dev/null; then
        cat "${FILE}".new > "${FILE}"
    fi
    rm "${FILE}".new
}

# Set a value for a shell variable in a config file.
# If the variable already exists, it will be replaced.
# If the variable does not yet exist, it will be appended (with a comment).
filevar_set_var()
{
    FILE="${1}"
    VAR="${2}"
    VAL="${3}"
    PVAL=`echo "${VAL}" | sed -r -e 's/\\\\/\\\\\\\\/g' -e 's/@/\\\\@/g'`
    PAT='^('${VAR}'=)"?([^"]*)"?[[:space:]]*$'
    if grep -qE "${PAT}" "${FILE}"; then
        sed_patch_file "${FILE}" -r 's@'"${PAT}"'@\1"'"${PVAL}"'"@g'
    else
        printf '#\n# added by %s-%s-%s\n%s="%s"\n' \
          "${RPM_PACKAGE_NAME}" "${RPM_PACKAGE_VERSION}" "${RPM_PACKAGE_RELEASE}" \
          "${VAR}" "${VAL}" >> "${FILE}"
    fi
}

# Like filevar_set_var() but appends the value instead of replacing it if it already exists
filevar_add_var()
{
    FILE="${1}"
    VAR="${2}"
    VAL="${3}"
    PVAL=`echo "${VAL}" | sed -r -e 's/\\\\/\\\\\\\\/g' -e 's/@/\\\\@/g'`
    PAT1='^('${VAR}'=)(""|)[[:space:]]*$'
    PAT2='^('${VAR}'=)"?([^"]+)"?[[:space:]]*$'
    if grep -qE "${PAT1}" "${FILE}"; then
        sed_patch_file "${FILE}" -r 's@'"${PAT1}"'@\1"'"${PVAL}"'"@g'
    elif grep -qE "${PAT2}" "${FILE}"; then
        if ! cat "${FILE}" | grep -E "${PAT2}" | sed -r 's@'"${PAT2}"'@\2@g' | grep -qwF -- "${VAL}"; then
            sed_patch_file "${FILE}" -r 's@'"${PAT2}"'@\1"'"\2 ${PVAL}"'"@g'
        fi
    else
        printf '#\n# added by %s-%s-%s\n%s="%s"\n' \
          "${RPM_PACKAGE_NAME}" "${RPM_PACKAGE_VERSION}" "${RPM_PACKAGE_RELEASE}" \
          "${VAR}" "${VAL}" >> "${FILE}"
    fi
}

# Like filevar_set_var() but does not put the value in quotes
filevar_set_var_noquote()
{
    FILE="${1}"
    VAR="${2}"
    VAL="${3}"
    PVAL=`echo "${VAL}" | sed -r -e 's/\\\\/\\\\\\\\/g' -e 's/@/\\\\@/g'`
    PAT='^#?('${VAR}'=)"?([^"]*)"?[[:space:]]*$'
    if grep -qE "${PAT}" "${FILE}"; then
        sed_patch_file "${FILE}" -r 's@'"${PAT}"'@\1'"${PVAL}"'@g'
    else
        printf '#\n# added by %s-%s-%s\n%s=%s\n' \
          "${RPM_PACKAGE_NAME}" "${RPM_PACKAGE_VERSION}" "${RPM_PACKAGE_RELEASE}" \
          "${VAR}" "${VAL}" >> "${FILE}"
    fi
}

# Disables a shell variable in a config file (i.e., comments it out).
# If the variable already exists, it will be commented out.
# If the variable does not yet exist, no action will be taken.
filevar_disable_var()
{
    FILE="${1}"
    VAR="${2}"
    COMMENT="${3:-#}"
    PAT1='^('"${VAR}"'=)(""|)[[:space:]]*$'
    PAT2='^('"${VAR}"'=)"?([^"]+)"?[[:space:]]*$'
    if grep -qE "${PAT1}" "${FILE}"; then
        sed_patch_file "${FILE}" -r 's@'"${PAT1}"'@"'"${COMMENT}"'"\1\2@g'
    elif grep -qE "${PAT2}" "${FILE}"; then
        sed_patch_file "${FILE}" -r 's@'"${PAT2}"'@"'"${COMMENT}"'\1"\2"@g'
    fi
}

# Enables a shell variable in a config file (i.e., uncomments it).
# If the variable already exists, and it is commented out, uncomment it.
# If the variable does not yet exist, no action will be taken.
filevar_enable_var()
{
    FILE="${1}"
    VAR="${2}"
    COMMENT="${3:-#}"
    PAT1='^('"${COMMENT}"')?('"${VAR}"'=)(""|)[[:space:]]*$'
    PAT2='^('"${COMMENT}"')?('"${VAR}"'=)"?([^"]+)"?[[:space:]]*$'
    if grep -qE "${PAT1}" "${FILE}"; then
        sed_patch_file "${FILE}" -r 's@'"${PAT1}"'@\2\3@g'
    elif grep -qE "${PAT2}" "${FILE}"; then
        sed_patch_file "${FILE}" -r 's@'"${PAT2}"'@\2"\3"@g'
    fi
}

# Replace a file with a symlink our own version, backing up the original if necessary
replace_file_symlink()
{
    TARGET="$1"
    SOURCE="$2"
    if [ -e "${TARGET}" -a ! -h "${TARGET}" -a ! -e "${TARGET}".orig ]; then
        mv "${TARGET}" "${TARGET}".orig
    fi
    if ! readlink "${TARGET}" >/dev/null 2>&1 || [ `readlink "${TARGET}"` != "${SOURCE}" ]; then
        rm -f "${TARGET}"
        ln -s "${SOURCE}" "${TARGET}"
    fi
}

# Function to add/update a RPM-specific section of a file
update_blurb()
{
    S_TARGET_FILE="$1"
    S_MARKER_PAT="$2"
    S_LABEL="$3"
    if [ -z "${S_LABEL}" ]; then
        S_LABEL="${RPM_PACKAGE_NAME}"
    fi
    S_START_MARKER='### BEGIN '"${S_LABEL}"' BLURB ###'
    S_STOP_MARKER='### END '"${S_LABEL}"' BLURB ###'
    S_START_LINENUM=`grep -Fn "${S_START_MARKER}" "${S_TARGET_FILE}" | head -n 1 | sed -rn 's/^([0-9]+):.*$/\1/gp'`
    if [ -n "${S_START_LINENUM}" ]; then
        head -n "`expr ${S_START_LINENUM} - 1`" "${S_TARGET_FILE}" > "${S_TARGET_FILE}".new
        echo "${S_START_MARKER}" >> "${S_TARGET_FILE}".new
        cat >> "${S_TARGET_FILE}".new
        echo "${S_STOP_MARKER}" >> "${S_TARGET_FILE}".new
        S_STOP_LINENUM=`grep -Fn "${S_STOP_MARKER}" "${S_TARGET_FILE}" | tail -n 1 | sed -rn 's/^([0-9]+):.*$/\1/gp'`
        if [ -n "${S_STOP_LINENUM}" ] && [ "${S_STOP_LINENUM}" -gt "${S_START_LINENUM}" ]; then
            tail -n +`expr ${S_STOP_LINENUM} + 1` "${S_TARGET_FILE}" >> "${S_TARGET_FILE}".new
        fi
    else
        if [ -n "${S_MARKER_PAT}" ]; then
            S_MARKER_LINE=`grep -En "${S_MARKER_PAT}" "${S_TARGET_FILE}" | head -n 1 | sed -rn 's/^([0-9]+):.*$/\1/gp'`
        fi
        if [ -z "${S_MARKER_LINE}" ]; then
            S_MARKER_LINE=`wc -l < "${S_TARGET_FILE}"`
        fi
        head -n "${S_MARKER_LINE}" "${S_TARGET_FILE}" > "${S_TARGET_FILE}".new
        echo "${S_START_MARKER}" >> "${S_TARGET_FILE}".new
        cat >> "${S_TARGET_FILE}".new
        echo "${S_STOP_MARKER}" >> "${S_TARGET_FILE}".new
        tail -n +`expr "${S_MARKER_LINE}" + 1` "${S_TARGET_FILE}" >> "${S_TARGET_FILE}".new
    fi
    if diff -q "${S_TARGET_FILE}" "${S_TARGET_FILE}".new >/dev/null; then
        rm -f "${S_TARGET_FILE}".new
    else
        cat "${S_TARGET_FILE}".new > "${S_TARGET_FILE}"
        rm -f "${S_TARGET_FILE}".new
    fi
}

#
# Function to remove the RPM-specific section of a file previously added via update_blurb
# Use it in a %preun section like this:
#
#   %preun
#
#   # Load handy scripts
#   . %{_datadir}/%{org_id}-rpm-scripts/rpm-scripts '%{name}' '%{version}' '%{release}'
#
#   # Remove blurb on uninstall
#   if [ "$1" -eq 0 ]; then
#       remove_blurb FILENAME
#   fi
#
remove_blurb()
{
    S_TARGET_FILE="$1"
    S_START_MARKER='### BEGIN '"${RPM_PACKAGE_NAME}"' BLURB ###'
    S_STOP_MARKER='### END '"${RPM_PACKAGE_NAME}"' BLURB ###'
    S_START_LINENUM=`grep -Fn "${S_START_MARKER}" "${S_TARGET_FILE}" | head -n 1 | sed -rn 's/^([0-9]+):.*$/\1/gp'`
    if [ -n "${S_START_LINENUM}" ]; then
        head -n "`expr ${S_START_LINENUM} - 1`" "${S_TARGET_FILE}" > "${S_TARGET_FILE}".new
        S_STOP_LINENUM=`grep -Fn "${S_STOP_MARKER}" "${S_TARGET_FILE}" | tail -n 1 | sed -rn 's/^([0-9]+):.*$/\1/gp'`
        if [ -n "${S_STOP_LINENUM}" ] && [ "${S_STOP_LINENUM}" -gt "${S_START_LINENUM}" ]; then
            tail -n +`expr ${S_STOP_LINENUM} + 1` "${S_TARGET_FILE}" >> "${S_TARGET_FILE}".new
        fi
        if diff -q "${S_TARGET_FILE}" "${S_TARGET_FILE}".new >/dev/null; then
            rm -f "${S_TARGET_FILE}".new
        else
            cat "${S_TARGET_FILE}".new > "${S_TARGET_FILE}"
            rm -f "${S_TARGET_FILE}".new
        fi
    fi
}

# Function to verify the checksum (by default, SHA1) of a given file;
# exits with an error value if not equal
verify_checksum()
{
    FILE="${1}"
    CHECKSUM1="${2}"
    DIGEST="${3}"
    if [ -z "${DIGEST}" ]; then
        DIGEST="sha1"
    fi
    CHECKSUM2=`openssl ${DIGEST} -r "${FILE}" | awk '{ print $1 }'`
    if [ "${CHECKSUM2}" != "${CHECKSUM1}" ]; then
        echo "${DIGEST} mismatch for ${FILE}: expected ${CHECKSUM1} but got ${CHECKSUM2}" 1>&2
        exit 1
    fi
}

# Do something to an init service, but only if that service is currently running
do_if_running()
{
    SERVICE="${1}"
    OPERATION="${2}"
    CHECKOP="${3}"
    if [ -z "${CHECKOP}" ]; then
        CHECKOP="status"
    fi
    if systemctl -q is-active "${SERVICE}"; then
        systemctl "${OPERATION}" "${SERVICE}"
    fi
}

# Function to create/update a system user
update_user()
{
    U_USERNAME="${1}"
    U_GROUPNAMES="${2}"
    U_HOME="${3:-/home/${U_USERNAME}}"
    U_SHELL="${4:-/sbin/nologin}"
    U_CRYPTED="*"

    if [ ! -d "${U_HOME}" ]; then
        MFLAG="-m"
    else
        MFLAG=""
    fi
    if ! id "${U_USERNAME}" >/dev/null 2>&1; then
        echo "*** Creating user ${U_USERNAME}"
        CMD="useradd"
    else
        CMD="usermod"
    fi
    ${CMD} -p "${U_CRYPTED}" -G "${U_GROUPNAMES}" ${MFLAG} -d "${U_HOME}" -s "${U_SHELL}" "${U_USERNAME}"
}

# Function to remove a system user
remove_user()
{
    U_USERNAME="${1}"

    # Get home directory
    HOMEDIR=$(getent passwd "${U_USERNAME}" | awk -F: '{ print $6 }')

    # Remove account
    echo "*** Removing account for user ${U_USERNAME}"
    userdel "${U_USERNAME}" 2>/dev/null || true

    # Remove home directory if empty, otherwise chown to root
    SKEL=$(useradd -D | sed -nr 's/^SKEL=(.*)$/\1/gp')
    if diff -urq \
      --exclude=.bash_history \
      --exclude=.bashrc \
      --exclude=.emacs \
      --exclude=.inputrc \
      --exclude=.profile \
      --exclude=.ssh \
      --exclude=.vimrc \
      "${SKEL}" "${HOMEDIR}" >/dev/null; then
        echo "*** Removing empty homedir for user ${U_USERNAME}"
        rm -rf "${HOMEDIR}"
    else
        echo "*** NOTE: user ${U_USERNAME} left a non-empty homedir (will be owned by root)"
        chown -R root:root "${HOMEDIR}"
    fi
}

# Function to remove system users in given system group, but not in given list (one username per line)
remove_old_users()
{
    U_GROUPNAME="${1}"
    U_USERS_FILE="${2}"

    # Delete any users in group who no longer have accounts
    getent group "${U_GROUPNAME}" | awk -F: '{ printf "%s,", $4 }' | while read -d, USERNAME; do

        # Sanity check
        if [ -z "${USERNAME}" ]; then
            continue
        fi

        # Is user still here?
        if grep -qE '^'"${USERNAME}"'([[:space:]].*|)$' "${U_USERS_FILE}"; then
            continue
        fi

        # Remove user
        remove_user "${USERNAME}"
    done
}

# Function to create/update a system group
update_group()
{
    G_NAME="${1}"
    if ! getent group "${G_NAME}" >/dev/null 2>&1; then
        echo "*** Creating group ${G_NAME}"
        groupadd "${G_NAME}"
    fi
}

# Function to remove a system group
remove_group()
{
    G_NAME="${1}"
    if ! getent group "${G_NAME}" >/dev/null 2>&1; then
        echo "*** Removing group ${G_NAME}"
        groupdel "${G_NAME}" 2>/dev/null || true
    fi
}

# Allow RPM variables to be set at include time
set_rpm_variables "$1" "$2" "$3"

