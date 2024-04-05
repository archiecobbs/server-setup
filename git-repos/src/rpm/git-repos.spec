
#
# Requires:
#   scm_revision
#   org_id
#   org_name
#   org_domain
#   repo_dir
#

%define pkgdir          %{_datadir}/%{name}

Name:               %{org_id}-git-repos
Version:            %(echo %{scm_revision} | tr - .)
Release:            1
Summary:            %{org_name} Git Repository Setup
Group:              System/Setup
License:            Apache-2.0
Distribution:       %{org_name} Server Setup
Source0:            source.zip
BuildRoot:          %{_tmppath}/%{name}-root
Buildarch:          noarch
URL:                http://%{org_domain}/

Requires:           git

%description
%{summary}.

This RPM sets up a directory for git repositories.

The RPM includes a script "create-new-git-repo" for creating new repositories.
New git repositories are configured to use UNIX groups for access control.

%clean
%{__rm} -rf %{buildroot}

%prep
%{__rm} -rf %{buildroot}
%setup -c

%build

# Generate script
subst()
{
    sed -r \
      -e 's|@org_id@|%{org_id}|g' \
      -e 's|@org_domain@|%{org_domain}|g' \
      -e 's|@email_script@|%{pkgdir}/multimail.py|g' \
      -e 's|@repo_dir@|%{repo_dir}|g'
}
subst < scripts/create-new-git-repo.sh > create-new-git-repo

%install

# Install script
install -d -m 0755 %{buildroot}/%{_bindir}
install -m 0755 create-new-git-repo %{buildroot}/%{_bindir}/

# Install email hook
install -d -m 0755 %{buildroot}/%{pkgdir}
install -m 0755 scripts/multimail.py %{buildroot}/%{pkgdir}/

%files
%attr(0755,root,root) %{_bindir}/*
%defattr(0644,root,root,0775)
%{pkgdir}
