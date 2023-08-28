
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
%define repobaseurl http://download.opensuse.org

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

# Verify RPM repo key exists
if ! [ -f repo/org/%{org_id}-repo.key ]; then
    cat << 'xxEOFxx'

    *****************************************************************************************

    You must first create an RPM repository package signing key. You can do this as follows:

      gpg2 --quick-gen-key '%{org_name} Package Signing Key' - sign never

    Supply a passphrase you will be comfortable typing every time you publish RPMs to the repo.

    Then add the public key to this project so it can be published in the repo:

      gpg2 --export-keys -a '%{org_name} Package Signing Key' > ./repo/org/%{org_id}-repo.key
      git add ./repo/org/%{org_id}-repo.key
      git comit -m 'Add RPM Package Signing Key'

    To provide this key to any others who will also sign packages:

      gpg2 --export-secret-keys -a '%{org_name} Package Signing Key' > %{org_id}-repo-secret.key

    You will have to enter your passphrase to decrypt the key, then another one to encrypt it
    for transport to the recipient.

    The recipient would then import the key like this:

      gpg2 --import %{org_id}-repo-secret.key

    They will also have to enter the transport passphrase and also their own new passphrase.

    *****************************************************************************************
xxEOFxx
    exit 1
fi

# Generate openSUSE repo files
mkdir -p repofiles
if [ '%{osrel}' = 'tumbleweed' ]; then
    REPO_TMPL_DIR='repo/%{osrel}'
else
    REPO_TMPL_DIR='repo/leap'
fi
find "${REPO_TMPL_DIR}" -maxdepth 1 -name '*.repo.in' | while read REPOFILE; do
    FNAME=`basename "${REPOFILE}" | sed -r 's/\.in$//g'`
    genrepo '%{osname}' '%{osrel}' '%{repobaseurl}' < "${REPOFILE}" > repofiles/"${FNAME}"
done

# Create %{org_name} repo file
genrepo '%{osname}' '%{osrel}' < repo/org/org.repo.in > repofiles/%{org_id}.repo

%install

# Install repo files
install -d -m 0755 %{buildroot}%{zyppdir}
install -m 0644 repofiles/*.repo %{buildroot}%{zyppdir}/

# Install %{org_name} repo public key
install -d -m 0755 %{buildroot}%{pkgdir}
install -m 0644 repo/org/%{org_id}-repo.key %{buildroot}%{pkgdir}/

%post
if [ "${1}" -eq 1 ]; then
    echo ''
    echo 'Run the following command to import the RPM signing key:'
    echo ''
    echo '    rpm --import %{pkgdir}/%{org_id}-repo.key'
    echo ''
fi

%files
%attr(-,root,root) %{zyppdir}/*
%defattr(0644,root,root,0775)
%{pkgdir}
