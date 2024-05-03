#!/bin/sh

# Bail on error
set -e

# Usage message
usage()
{
    echo "Usage: genkey [-u username]" 1>&2
    echo "Options:" 1>&2
    echo "  -u          Specify username (default \"${USER}\")" 1>&2
    echo "  --setup     Create entry in @otpfile@ and initialize user's ~/.genfile file" 1>&2
    echo "  --issuer    Specify token issuer when using \`--setup' (default \`@org_name@')" 1>&2
    echo "  --label     Specify token label when using \`--setup' (default \`<username>@@web_hostname@')" 1>&2
}

# Parse flags passed in on the command line
USERNAME="${USER}"
SETUP="false"
ISSUER=""
LABEL=""
while [ ${#} -gt 0 ]; do
    case "$1" in
        -u)
            shift
            USERNAME="${1}"
            shift
            ;;
        --issuer)
            shift
            ISSUER="${1}"
            shift
            ;;
        --label)
            shift
            LABEL="${1}"
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

# Apply defaults
if [ "${ISSUER}" = "" ]; then
    ISSUER='@org_name@'
fi
if [ "${LABEL}" = "" ]; then
    LABEL="${USERNAME}"'@@web_hostname@'
fi

# Key file
KEYFILE="/home/${USERNAME}/.genkey"

# Check permissions
if [ `id -u` -ne 0 ]; then
    if [ "${USERNAME}" != "${USER}" ]; then
        echo "Error: must be root to access another user's key" 1>&2
        exit 1
    fi
    if [ "${SETUP}" = 'true' ]; then
        echo "Error: must be root to install new keys" 1>&2
        exit 1
    fi
fi

# OTP file pattern
PAT='^HOTP(/(E|T([0-9]+))(/([0-9]))?)?[[:space:]]+([^[:space:]]+)[[:space:]]*$'

# Setup mode?
if [ "${SETUP}" = 'true' ]; then

    # Create random key and user to users.txt
    KEY=`head -c 20 /dev/random | openssl sha1 -r | cut -c 1-20`
    grep -vE '^[^[:space:]]+[[:space:]]+'"${USERNAME}"'[[:space:]]' '@otpfile@' > '@otpfile@'.new || true
    printf 'HOTP/T30 %s + %s\n' "${USERNAME}" "${KEY}" >> '@otpfile@'.new
    cat '@otpfile@'.new > '@otpfile@'
    rm -f '@otpfile@'.new

    # Copy key info from users.txt into ~/.genkey
    rm -f "${KEYFILE}"
    touch "${KEYFILE}"
    chmod 600 "${KEYFILE}"
    chown "${USERNAME}" "${KEYFILE}"
    sed -rn 's|([^[:space:]]+)[[:space:]]+'"${USERNAME}"'[[:space:]]+[^[:space:]]+[[:space:]]+([^[:space:]]+).*|\1 \2|gp' \
      < '@otpfile@' > "${KEYFILE}"
fi

# See if key file is readable
if ! test -r "${KEYFILE}"; then
    echo "genkey: can't read ${KEYFILE}" 1>&2
    exit 1
fi

# Parse keyfile to get token type and key
TYPE=`head -n 1 "${KEYFILE}" | sed -rn 's%'"${PAT}"'%\3%gp'`
TKEY=`head -n 1 "${KEYFILE}" | sed -rn 's%'"${PAT}"'%\6%gp'`
if [ -z "${TYPE}" -o -z "${TKEY}" ]; then
    echo "genkey: can't parse ${KEYFILE}" 1>&2
    exit 1
fi

# Get token interval
TINTERVAL=`head -n 1 "${KEYFILE}" | sed -rn 's%'"${PAT}"'%\3%gp'`
if [ "${TINTERVAL}" != '30' ]; then
    echo "genkey: can only handle time-based tokens with 30 second interval" 1>&2
    exit 1
fi

# Get number of digits
TDIGITS=`head -n 1 "${KEYFILE}" | sed -rn 's%'"${PAT}"'%\5%gp'`
[ -z "${TDIGITS}" ] && TDIGITS="6"
if [ "${TDIGITS}" != '6' ]; then
    echo "genkey: can only handle six digit tokens" 1>&2
    exit 1
fi

if [ "${SETUP}" = 'true' ]; then

    # Generate Google Authenticator URL
    genotpurl \
        -I "${ISSUER}" \
        -L "${LABEL}" \
        -k "${TKEY}" \
        -d "${TDIGITS}" \
        -p "${TINTERVAL}"
else

    # Generate token
    exec otptool -d "${TDIGITS}" -t -i "${TINTERVAL}" "${TKEY}" | awk '{ print $2 }'
fi
