#!/bin/sh
# $Id: genkey.sh 201 2013-04-10 19:36:07Z archie $

# Bail on error
set -e

# Usage message
usage()
{
    echo "Usage: genkey [-u username]" 1>&2
    echo "Options:" 1>&2
    echo "  -u          Specify username (default \"${USER}\")" 1>&2
    echo "  --create    Create entry in @otpfile@ (implies \`--setup')" 1>&2
    echo "  --setup     Initialize user's ~/.genkey file from @otpfile@" 1>&2
    echo "  --url       Print out URL for OATH Token iPhone app" 1>&2
}

# Parse flags passed in on the command line
USERNAME="${USER}"
SETUP="false"
GENURL="false"
CREATE="false"
while [ ${#} -gt 0 ]; do
    case "$1" in
        -u)
            shift
            USERNAME="${1}"
            shift
            ;;
        --url)
            GENURL="true"
            shift
            ;;
        --create)
            CREATE="true"
            SETUP="true"
            shift
            ;;
        --setup)
            SETUP="true"
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
    0)
        ;;
    *)
        usage
        exit 1
        ;;
esac

# Key file
KEYFILE="/home/${USERNAME}/.genkey"

# Setup mode?
if [ "${SETUP}" = 'true' ]; then
    if [ "${CREATE}" = 'true' ]; then
        KEY=`head -c 12 /dev/random | openssl sha1 -r | cut -c 1-24`
        printf 'HOTP/T60 %s + %s\n' "${USERNAME}" "${KEY}" >> '@otpfile@'
    fi
    touch "${KEYFILE}"
    chmod 600 "${KEYFILE}"
    sed -rn 's|([^[:space:]]+)[[:space:]]+'"${USERNAME}"'[[:space:]]+[^[:space:]]+[[:space:]]+([^[:space:]]+).*|\1 \2|gp' \
      < '@otpfile@' > "${KEYFILE}"
fi

# See if key file is readable
if ! test -r "${KEYFILE}"; then
    echo "genkey: can't read ${KEYFILE}" 1>&2
    exit 1
fi

# Parse keyfile to get token type and key
PAT='^HOTP(/(E|T([0-9]+))(/([0-9]))?)?[[:space:]]+([^[:space:]]+)[[:space:]]*$'
TYPE=`sed -rn 's%'"${PAT}"'%\3%gp' "${KEYFILE}"`
TKEY=`sed -rn 's%'"${PAT}"'%\6%gp' "${KEYFILE}"`
if [ -z "${TYPE}" -o -z "${TKEY}" ]; then
    echo "genkey: can't parse ${KEYFILE}" 1>&2
    exit 1
fi

# Get token interval
TINTERVAL=`sed -rn 's%'"${PAT}"'%\3%gp' "${KEYFILE}"`
if [ -z "${TINTERVAL}" ]; then
    echo "genkey: can't handle event-based tokens" 1>&2
    exit 1
fi

# Get number of digits
TDIGITS=`sed -rn 's%'"${PAT}"'%\5%gp' "${KEYFILE}"`
[ -z "${TDIGITS}" ] && TDIGITS="6"

# Generate iPhone app URL if --url specified
if [ "${GENURL}" = 'true' ]; then
    exec genotpurl -k "${TKEY}" -d "${TDIGITS}" -i "${TINTERVAL}" -n '@org_name@'
fi

# Generate token
exec otptool -d "${TDIGITS}" -t -i "${TINTERVAL}" "${TKEY}" | awk '{ print $2 }'

