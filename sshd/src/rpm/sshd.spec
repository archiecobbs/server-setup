
#
# Requires:
#   scm_revision
#   osname
#   osrel
#   org_id
#   org_name
#   org_domain
#

%define sshd_config         %{_sysconfdir}/ssh/sshd_config
%if "%{osrel}" >= "15.6"
%define sshd_config_d       %{_sysconfdir}/ssh/sshd_config.d
%define sshd_config_pl      %{sshd_config_d}/%{name}.conf
%endif

Name:               %{org_id}-sshd
Version:            %(echo %{scm_revision} | tr - .)
Release:            1.%{osname}%{osrel}
Summary:            %{org_name} sshd(8) system configuration (%{osname}%{osrel})
Group:              System/Setup
License:            Apache-2.0
Distribution:       %{org_name} Server Setup
BuildRoot:          %{_tmppath}/%{name}-root
Buildarch:          noarch
URL:                http://%{org_domain}/

Requires(post):     openssh
Requires(post):     %{org_id}-rpm-scripts

%description
%{summary}.

%clean
rm -rf %{buildroot}

%prep
rm -rf %{buildroot}

%install

%if "%{osrel}" >= "15.6"
install -d -m 0755 `dirname %{buildroot}%{sshd_config_pl}`
cat > %{buildroot}%{sshd_config_pl} << 'xxEOFxx'
# This file is part of %{name}-%{version}-%{release}

PasswordAuthentication no
PermitRootLogin no
UseDNS no
TCPKeepAlive yes
KbdInteractiveAuthentication no
ClientAliveInterval 9
ClientAliveCountMax 3
MaxSessions 500
MaxStartups 25:20:100
xxEOFxx

%endif

%post

# Load handy scripts
. %{_datadir}/%{org_id}-rpm-scripts/rpm-scripts '%{name}' '%{version}' '%{release}'

%if "%{osrel}" < "15.6"

# Save original ssh config just in case
[ -e %{sshd_config}.old ] || cp -a %{sshd_config}{,.old}

# Set these SSHD parameters
update_blurb %{sshd_config} << xxEOFxx
PasswordAuthentication no
PermitRootLogin no
UseDNS no
TCPKeepAlive yes
ChallengeResponseAuthentication no
ClientAliveInterval 9
ClientAliveCountMax 3
MaxSessions 500
MaxStartups 25:20:100
xxEOFxx

# Avoid conflicting parameters for 'PermitRootLogin', etc.
# Restore original "UsePAM yes" which was previously set to "no"
sed_patch_file %{sshd_config} -r \
  -e 's/^(UsePAM[[:space:]]+)no/\1yes/g' \
  -e 's/^(PermitRootLogin[[:space:]]+)yes/\1no/g' \
  -e 's/^(PasswordAuthentication[[:space:]]+)yes/\1no/g' \
  -e 's/^(ChallengeResponseAuthentication[[:space:]]+)yes/\1no/g'

%endif

# Ensure SSH service is enabled
systemctl enable sshd.service

%files
%defattr(0644,root,root,0755)
%if "%{osrel}" >= "15.6"
%{sshd_config_pl}
%endif
