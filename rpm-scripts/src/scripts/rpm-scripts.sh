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

# Function that patches a file using sed(1).
# First argument is filename, subsequent arguments are passed to sed(1).
sed_patch_file()
{
    FILE="${1}"
    shift
    sed ${1+"$@"} < "${FILE}" > "${FILE}".new
    if ! diff -q "${FILE}" "${FILE}".new >/dev/null; then
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
    VAL=`echo "${3}" | sed -r 's/@/\\\\@/g'`
    PAT='^('${VAR}'=)"?([^"]*)"?[[:space:]]*$'
    if grep -qE "${PAT}" "${FILE}"; then
        sed_patch_file "${FILE}" -r 's@'"${PAT}"'@\1"'"${VAL}"'"@g'
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
    VAL=`echo "${3}" | sed -r 's/@/\\\\@/g'`
    PAT1='^('${VAR}'=)(""|)[[:space:]]*$'
    PAT2='^('${VAR}'=)"?([^"]+)"?[[:space:]]*$'
    if grep -qE "${PAT1}" "${FILE}"; then
        sed_patch_file "${FILE}" -r 's@'"${PAT1}"'@\1"'"${VAL}"'"@g'
    elif grep -qE "${PAT2}" "${FILE}"; then
        if ! cat "${FILE}" | grep -E "${PAT2}" | sed -r 's@'"${PAT2}"'@\2@g' | grep -qwF -- "${VAL}"; then
            sed_patch_file "${FILE}" -r 's@'"${PAT2}"'@\1"'"\2 ${VAL}"'"@g'
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
    VAL=`echo "${3}" | sed -r 's/@/\\\\@/g'`
    PAT='^('${VAR}'=)"?([^"]*)"?[[:space:]]*$'
    if grep -qE "${PAT}" "${FILE}"; then
        sed_patch_file "${FILE}" -r 's@'"${PAT}"'@\1'"${VAL}"'@g'
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

# Function to remove the RPM-specific section of a file previously added via update_blurb
# Use it in a %preun section like this:
#
#   %preun
#   set_rpm_variables '%{name}' '%{version}' '%{release}'
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
    if /etc/init.d/"${SERVICE}" "${CHECKOP}" >/dev/null 2>&1; then
        /etc/init.d/"${SERVICE}" "${OPERATION}"
    fi
}

# Allow RPM variables to be set at include time
set_rpm_variables "$1" "$2" "$3"

