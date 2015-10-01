#!/bin/bash

set -e

# Bail on error
set -e

# Get default info
SEDFLAG="r"
if [ `uname -s` = 'Darwin' ]; then
    SEDFLAG="E"
fi
DOMAIN=`sed -${SEDFLAG}n 's/^org.domain=([^[:space:]]+).*$/\1/gp' ../build.properties`
CERTHOST=`sed -${SEDFLAG}n 's/^web.hostname=([^[:space:]]+).*$/\1/gp' ../build.properties`
ORG_NAME=`sed -${SEDFLAG}n 's/^org.name=(.*)$/\1/gp' ../build.properties`
EMAIL="support@${DOMAIN}"
COUNTRY="US"
STATE="California"
CITY="Los Angeles"

# Usage message
usage()
{
    echo "Usage: ${0} [options] [hostname]" 1>&2
    echo "Options:" 1>&2
    echo "  --self-sign     Self-sign the newly created key" 1>&2
    echo "  --email addr    Specify email address (default \`${EMAIL}')" 1>&2
    echo "  --country name  Specify country (default \`${COUNTRY}')" 1>&2
    echo "  --state name    Specify state/province (default \`${STATE}')" 1>&2
    echo "  --city name     Specify city/locality (default \`${CITY}')" 1>&2
    echo "  --help          Show this help info" 1>&2
    echo "This script generates a new private key and corresponding certificate sigining request." 1>&2
    echo "Specify hostname in the format \`*.example.com' for a wildcard certificate." 1>&2
    echo "If not specified, the default hostname is \`${CERTHOST}'." 1>&2
}

# Parse flags passed in on the command line
SELF_SIGN="false"
while [ ${#} -gt 0 ]; do
    case "$1" in
        --country)
            shift
            COUNTRY="$1"
            shift
            ;;
        --state)
            shift
            STATE="$1"
            shift
            ;;
        --city)
            shift
            CITY="$1"
            shift
            ;;
        --email)
            shift
            EMAIL="$1"
            shift
            ;;
        --self-sign)
            SELF_SIGN="true"
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
        CERTHOST="${1}"
        ;;
    0)
        ;;
    *)
        usage
        exit 1
        ;;
esac

# Create temporary config file
CONFIG_FILE=`mktemp -q /tmp/new-key-and-csr.XXXXXX`
if [ $? -ne 0 ]; then
    echo "${0}: can't create temporary file" 1>&2
    exit 1
fi
trap "rm -f ${CONFIG_FILE}" 0 2 3 5 10 13 15
cat > "${CONFIG_FILE}" << xxEOFxx
[ req ]
default_bits = 2048
distinguished_name = req_distinguished_name
prompt = no

[ req_distinguished_name ]
O = ${ORG_NAME}
CN = ${CERTHOST}
emailAddress = ${EMAIL}
xxEOFxx
if [ -n "${COUNTRY}" ]; then
    echo "C = ${COUNTRY}" >> "${CONFIG_FILE}"
fi
if [ -n "${STATE}" ]; then
    echo "ST = ${STATE}" >> "${CONFIG_FILE}"
fi
if [ -n "${CITY}" ]; then
    echo "L = ${CITY}" >> "${CONFIG_FILE}"
fi

echo =============
cat "${CONFIG_FILE}"
echo =============

# Generate key and CSR
if [ -e src/ssl/web.key ]; then
    mv src/ssl/web.key{,.old}
fi
echo "Creating new private key and certificate signing request..." 1>&2
openssl req -config "${CONFIG_FILE}" \
  -out src/ssl/web.csr -new -newkey rsa:2048 -nodes \
  -keyout src/ssl/web.key

# Optionally self-sign
if [ "${SELF_SIGN}" = 'true' ]; then
    echo "Creating self-signed certificate..." 1>&2
    openssl x509 -in src/ssl/web.csr -out src/ssl/web.crt -req -signkey src/ssl/web.key -days 3650
    rm -f src/ssl/web.csr
fi

