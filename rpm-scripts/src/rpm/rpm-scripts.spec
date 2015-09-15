
#
# Requires:
#   gitrev
#   osname
#   osrel
#   org_id
#   org_name
#   org_domain
#

%define pkgdir      %{_datadir}/%{name}

Name:               %{org_id}-rpm-scripts
Version:            %{gitrev}
Release:            1.%{osname}%{osrel}
Summary:            %{org_name} RPM scripts
Group:              Development/Tools
License:            Apache-2.0
Distribution:       %{org_name} Server Setup
Source0:            source.zip
BuildRoot:          %{_tmppath}/%{name}-root
Buildarch:          noarch
URL:                http://%{org_domain}/

Requires:           diffutils
Requires:           grep
Requires:           sed

%description
%{summary}.

Used by other RPMs to perform common tasks within RPM scriptlets.

%clean
rm -rf %{buildroot}

%prep
rm -rf %{buildroot}
%setup -c

%install
install -m 0755 -d %{buildroot}%{pkgdir}
install -m 0644 scripts/rpm-scripts.sh %{buildroot}%{pkgdir}/rpm-scripts

%files
%defattr(0755,root,root,0755)
%{pkgdir}

