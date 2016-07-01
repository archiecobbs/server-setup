
#
# Requires:
#   gitrev
#   osname
#   osrel
#   org_id
#   org_name
#   org_domain
#

%define sshd_config %{_sysconfdir}/ssh/sshd_config
%define sshdver     6.6p1

Name:               %{org_id}-sshd
Version:            %(echo %{gitrev} | tr - .)
Release:            1.%{osname}%{osrel}
Summary:            %{org_name} sshd(8) system configuration (%{osname}%{osrel})
Group:              System/Setup
License:            Apache-2.0
Distribution:       %{org_name} Server Setup
BuildRoot:          %{_tmppath}/%{name}-root
Buildarch:          noarch
URL:                http://%{org_domain}/

Requires(post):     openssh >= %{sshdver}
Requires(post):     %{org_id}-rpm-scripts

%description
%{summary}.

%clean
rm -rf %{buildroot}

%prep
rm -rf %{buildroot}

%post

# Load handy scripts
. %{_datadir}/%{org_id}-rpm-scripts/rpm-scripts '%{name}' '%{version}' '%{release}'

# Save original ssh config just in case
[ -e %{sshd_config}.old ] || cp -a %{sshd_config}{,.old}

# Set these SSHD parameters
update_blurb %{sshd_config} << xxEOFxx
PasswordAuthentication no
PermitRootLogin no
UsePAM no
UseDNS no
TCPKeepAlive yes
ChallengeResponseAuthentication no
ClientAliveInterval 20
ClientAliveCountMax 3
xxEOFxx

# Avoid conflicting parameters for 'UsePAM'
sed_patch_file %{sshd_config} -r 's/^UsePAM yes/UsePAM no/g'

# Ensure SSH service is enabled
systemctl enable sshd.service

%files
%defattr(0644,root,root,0755)
