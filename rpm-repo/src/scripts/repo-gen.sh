
# Function to generate a repo file from a template by substituting @FOO@ variables
genrepo()
{
    # Get O/S name and version
    OS_NAME="$1"
    OS_REL="$2"
    REPO_BASE_URL="$3"

    # Substitute values into template
    sed -r \
      -e 's|@ORG_NAME@|'"${ORG_NAME}"'|g' \
      -e 's|@ORG_ID@|'"${ORG_ID}"'|g' \
      -e 's|@REPO_HOST@|'"${REPO_HOST}"'|g' \
      -e 's|@REPO_URLPATH@|'"${REPO_URLPATH}"'|g' \
      -e 's|@REPO_USERNAME@|'"${REPO_USERNAME}"'|g' \
      -e 's|@REPO_PASSWORD@|'"${REPO_PASSWORD}"'|g' \
      -e 's#@repobaseurl@#'"${REPO_BASE_URL}"'#g' \
      -e 's|@URL_AUTH_PREFIX@|'"${URL_AUTH_PREFIX}"'|g' \
      -e 's|@osname@|'"${OS_NAME}"'|g' \
      -e 's|@osrel@|'"${OS_REL}"'|g'
}

# Set genrepo params
ORG_NAME="$1"
ORG_ID="$2"
REPO_HOST="$3"
REPO_URLPATH="$4"
REPO_USERNAME="rpmrepo"
REPO_PASSWORD="$5"

if [ -n "${REPO_PASSWORD}" ]; then
    URL_AUTH_PREFIX="${REPO_USERNAME}:${REPO_PASSWORD}@"
else
    URL_AUTH_PREFIX=""
fi

