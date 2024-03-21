
#
# Requires:
#   scm_revision
#   org_id
#   org_name
#   org_domain
#   repo_host
#   repo_dir
#   repo_pass
#   os_name
#   os_versions
#

%define pkgdir          %{_datadir}/%{name}
%define apconfdir       %{_sysconfdir}/apache2/conf.d
%define orgwebincdir    %{_datadir}/%{org_id}-web/apache

Name:               %{org_id}-rpm-repo
Version:            %(echo %{scm_revision} | tr - .)
Release:            1
Summary:            %{org_name} RPM Repository Setup
Group:              System/Setup
License:            Apache-2.0
Distribution:       %{org_name} Server Setup
Source0:            source.zip
BuildRoot:          %{_tmppath}/%{name}-root
Buildarch:          noarch
URL:                http://%{org_domain}/

BuildRequires:      openssl
BuildRequires:      apache2-utils

Requires(pre):      pwdutils
Requires(post):     findutils
Requires(post):     createrepo_c >= 0.16.0

%description
%{summary}.

This RPM should be installed on the server hosting the RPM repository.
It defines the RPM repository directory layout under %{repo_dir}.

%clean
%{__rm} -rf %{buildroot}

%prep
%{__rm} -rf %{buildroot}
%setup -c

%build

# Verify RPM repo key exists
if ! [ -f repo/org/%{org_id}-repo.key ]; then
    cat << 'xxEOFxx'

    *****************************************************************************************

    You must first create an RPM repository package signing key. You can do this as follows:

      gpg2 --quick-gen-key '%{org_name} Package Signing Key' - sign never

    Supply a passphrase you will be comfortable typing every time you publish RPMs to the repo.

    Then add the public key to this project so it can be published in the repo:

      gpg2 --export -a '%{org_name} Package Signing Key' > ./src/repo/org/%{org_id}-repo.key
      git add ./src/repo/org/%{org_id}-repo.key
      git commit -m 'Add RPM Package Signing Key'

    To provide this key to any others who will also sign packages:

      gpg2 --export-secret-keys -a '%{org_name} Package Signing Key' > %{org_id}-repo-secret.key

    You will have to enter your passphrase to decrypt the key. The exported file is sensitive
    so you be careful to prevent anyone else from accessing it.

    The recipient would then import the key like this:

      gpg2 --import %{org_id}-repo-secret.key

    They will also have to enter a passphrase and also their own new passphrase.

    *****************************************************************************************
xxEOFxx
    exit 1
fi

# Load repo username & password function
. scripts/repo-gen.sh '%{org_name}' '%{org_id}' '%{repo_host}' '%{repo_urlpath}' '%{?repo_pass}'

# Create organization repo files
for OS_REL in `echo %{os_versions} | tr , ' '`; do
    mkdir -p repo/"${OS_REL}"
    genrepo '%{os_name}' "${OS_REL}" < repo/org/org.repo.in > repo/"${OS_REL}"/%{org_id}.repo
done

# Generate htpasswd file
touch htpasswd.txt
if [ -n "${REPO_PASSWORD}" ]; then
    htpasswd2 -Bbn "${REPO_USERNAME}" "${REPO_PASSWORD}" | grep . > htpasswd.txt
fi

# Generate apache config file
subst()
{
    sed -r \
      -e 's|@org_id@|%{org_id}|g' \
      -e 's|@org_name@|%{org_name}|g' \
      -e 's|@pkgdir@|%{pkgdir}|g' \
      -e 's|@repodir@|%{repo_dir}|g' \
      -e 's|@repourlpath@|%{repo_urlpath}|g'
}
subst < apache/org-rpmrepo-auth-provider.conf > %{org_id}-rpmrepo-auth-provider.conf
subst < apache/org-rpmrepo.include > %{org_id}-rpmrepo.port443.include

# Generate properties file
printf 'os.versions=' '%{os_versions}' > repo.properties
COMMA=""
for OS_REL in `echo %{os_versions} | tr , ' '`; do
    printf '%s%s' "${COMMA}" "${OS_REL}" >> repo.properties
    COMMA=","
done
printf '\n' >> repo.properties

%install

# Create repository directory layout
install -d %{buildroot}%{repo_dir}
for OS_REL in `echo %{os_versions} | tr , ' '`; do
    REPODIR="%{buildroot}/%{repo_dir}/${OS_REL}"
    install -d -m 0755 "${REPODIR}"
    install -d -m 0755 "${REPODIR}"/{i{3,5}86,x86_64,noarch,src,repodata,cache}
    install -m 0644 repo/"${OS_REL}"/%{org_id}.repo "${REPODIR}"/
    install -m 0644 repo/org/%{org_id}-repo.key "${REPODIR}"/repodata/
done

# Properties file
install repo.properties %{buildroot}%{repo_dir}/

# Apache config files
install -d %{buildroot}%{pkgdir}/apache
install htpasswd.txt %{buildroot}%{pkgdir}/apache/
install -d %{buildroot}%{apconfdir}
install %{org_id}-rpmrepo-auth-provider.conf %{buildroot}%{apconfdir}/
install -d %{buildroot}%{orgwebincdir}
install %{org_id}-rpmrepo.port443.include %{buildroot}%{orgwebincdir}/

# Install scripts
install -d -m 0755 %{buildroot}/%{_bindir}
for NAME in repo-{rebuild,sign-rpms}; do
    FILE="%{buildroot}/%{_bindir}/${NAME}"
    install -m 0755 scripts/"${NAME}".sh "${FILE}"
    sed -i \
      -e 's|@repo_dir@|%{repo_dir}|g' \
      -e 's|@org_name@|%{org_name}|g' \
      "${FILE}"
done

%pre
# Create repo group
%{__grep} -q ^rpmrepo: /etc/group || groupadd rpmrepo

%post

# Create initial meta-data if needed
for OS_REL in `echo %{os_versions} | tr , ' '`; do
    REPODIR="%{repo_dir}/${OS_REL}"
    if ! [ -e "${REPODIR}"/repodata/repomd.xml ]; then
        createrepo -q "${REPODIR}"
    fi
done

# Fix permissions
chgrp -R rpmrepo %{repo_dir}/*
find %{repo_dir}/* -mindepth 2 -perm 444 -o -print0 | xargs -0r chmod g+w 
find %{repo_dir}/* -type d -print0 | xargs -0r chmod g+s 
chmod 644 %{repo_dir}/*/repodata/%{org_id}-repo.key

# Reload apache (if present)
if systemctl is-active apache2.service >/dev/null; then
    systemctl reload-or-try-restart apache2.service
fi

%files
%attr(0775,root,root) %dir %{repo_dir}
%attr(2775,root,rpmrepo) %dir %{repo_dir}/*
%attr(2775,root,rpmrepo) %{repo_dir}/*/[a-qs-z]*
%attr(2775,root,rpmrepo) %verify(not user) %{repo_dir}/*/repodata
%attr(0644,root,rpmrepo) %{repo_dir}/*/*.repo
%attr(0644,root,rpmrepo) %{repo_dir}/*.properties
%attr(0644,root,rpmrepo) %{repo_dir}/*/repodata/%{org_id}-repo.key
%attr(0755,root,root) %{_bindir}/*
%defattr(0644,root,root,0775)
%{pkgdir}
%{orgwebincdir}/*
%{apconfdir}/*
