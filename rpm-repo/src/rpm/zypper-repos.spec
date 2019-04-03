
#
# Requires:
#   scm_revision
#   osname
#   osrel
#   org_id
#   org_name
#   org_domain
#   repo_host
#   repo_pass
#

%define zyppdir     %{_sysconfdir}/zypp/repos.d 

Name:               %{org_id}-zypper-repos
Version:            %(echo %{scm_revision} | tr - .)
Release:            1.%{osname}%{osrel}
Summary:            %{org_name} zypper repositories for %{osname} %{osrel}
Group:              System/Setup
License:            Apache-2.0
Distribution:       %{org_name} Server Setup
Source:             source.zip
BuildRoot:          %{_tmppath}/%{name}-root
BuildRequires:      openssl
Buildarch:          noarch
URL:                http://%{org_domain}/

%description
%{summary}.

This RPM provides the *.repo files for the %{osname} %{osrel}
and %{org_name} zypper repositories.

%clean
%{__rm} -rf %{buildroot}

%prep
%{__rm} -rf %{buildroot}
%setup -c

%build

# Load repo username & password function
. scripts/repo-gen.sh '%{org_name}' '%{org_id}' '%{repo_host}' '%{repo_urlpath}' '%{?repo_pass}'

# Generate openSUSE repo files
mkdir -p repofiles
if [ '%{osrel}' = 'tumbleweed' ]; then
    REPO_TMPL_DIR='repo/%{osrel}'
else
    REPO_TMPL_DIR='repo/leap'
fi
find "${REPO_TMPL_DIR}" -maxdepth 1 -name '*.repo.in' | while read REPOFILE; do
    FNAME=`basename "${REPOFILE}" | sed -r 's/\.in$//g'`
    genrepo '%{osname}' '%{osrel}' < "${REPOFILE}" > repofiles/"${FNAME}"
done

# Create %{org_name} repo file
genrepo '%{osname}' '%{osrel}' < repo/org/org.repo.in > repofiles/%{org_id}.repo

%install

# Install repo files
install -d -m 0755 %{buildroot}%{zyppdir}
install -m 0644 repofiles/*.repo %{buildroot}%{zyppdir}/

%files
%attr(-,root,root) %{zyppdir}/*
