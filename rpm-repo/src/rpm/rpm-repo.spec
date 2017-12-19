
#
# Requires:
#   gitrev
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
Version:            %(echo %{gitrev} | tr - .)
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
Requires:           createrepo >= 0.10

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

# Load repo username & password function
. scripts/repo-gen.sh '%{org_name}' '%{org_id}' '%{repo_host}' '%{repo_urlpath}' '%{?repo_pass}'

# Create organization repo files
for OSVER in `echo %{os_versions} | tr , ' '`; do
    mkdir -p repo/"${OSVER}"
    genrepo "${OSVER}" < repo/org/org.repo.in > repo/"${OSVER}"/%{org_id}.repo
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
for OSVER in `echo %{os_versions} | tr , ' '`; do
    printf '%s%s%s' "${COMMA}" '%{os_name}' "${OSVER}" >> repo.properties
    COMMA=","
done
printf '\n' >> repo.properties

%install

# Create repository directory layout
install -d %{buildroot}%{repo_dir}
for OSVER in `echo %{os_versions} | tr , ' '`; do
    install -d -m 0755 %{buildroot}%{repo_dir}/'%{os_name}'"${OSVER}"
    install -d -m 0755 %{buildroot}%{repo_dir}/'%{os_name}'"${OSVER}"/{i{3,5}86,x86_64,noarch,src,repodata,cache}
    install -m 0644 repo/"${OSVER}"/%{org_id}.repo %{buildroot}%{repo_dir}/'%{os_name}'"${OSVER}"/
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

%pre
# Create repo group
%{__grep} -q ^rpmrepo: /etc/group || groupadd rpmrepo

%post

# Fix permissions
chgrp -R rpmrepo %{repo_dir}/*
find %{repo_dir}/* -mindepth 2 -perm 444 -o -print0 | xargs -0r chmod g+w 
find %{repo_dir}/* -type d -print0 | xargs -0r chmod g+s 

# Reload apache (if present)
if systemctl is-active apache2.service >/dev/null; then
    systemctl reload-or-try-restart apache2.service
fi

%files
%attr(2775,root,rpmrepo) %{repo_dir}/*
%verify(not owner) %{repo_dir}/*/repodata
%attr(0644,root,rpmrepo) %{repo_dir}/*/*.repo
%attr(0644,root,rpmrepo) %{repo_dir}/*.properties
%defattr(0644,root,root,0775)
%dir %{repo_dir}
%{pkgdir}
%{orgwebincdir}/*
%{apconfdir}/*

