
#
# Requires:
#   scm_revision
#   osname
#   osrel
#   org_id
#   org_name
#   org_domain
#

%define antconf     %{_sysconfdir}/ant.conf

Name:               %{org_id}-developer
Version:            %(echo %{scm_revision} | tr - .)
Release:            1.%{osname}%{osrel}
Summary:            %{org_name} Developer Setup (%{osname}%{osrel})
Group:              Development/Tools
License:            Apache-2.0
Distribution:       %{org_name} Server Setup
Source0:            source.zip
BuildRoot:          %{_tmppath}/%{name}-root
Buildarch:          noarch
URL:                http://%{org_domain}/

# Standard packages
Requires(post):     ant
Requires:           ant-apache-xalan2
Requires:           ant-contrib
Requires:           antlr
Requires:           ctags
Requires:           findutils-locate
Requires:           git
Requires:           apache-ivy >= 2.4.0
Requires:           java-devel-openjdk >= 1.8.0
Requires:           libxslt
Requires:           rpm
Requires:           rpm-build
Requires:           saxon9-scripts
Requires:           strace
Requires:           xalan-j2
Requires:           xerces-j2
Requires:           xmlstarlet

# Server Setup stuff
Requires:           %{org_id}-rpm-scripts
Requires:           %{org_id}-system

# Conflicting packages
Conflicts:          ant-antlr

%description
%{summary}

%prep
%setup -c

%post

# Load handy scripts
. %{_datadir}/%{org_id}-rpm-scripts/rpm-scripts '%{name}' '%{version}' '%{release}'

# Increase ant memory
filevar_add_var %{antconf} ANT_OPTS "-Xmx1024M"

%clean
rm -rf %{buildroot}

%files

