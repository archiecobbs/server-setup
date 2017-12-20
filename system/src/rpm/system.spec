
#
# Requires:
#   gitrev
#   osname
#   osrel
#   org_id
#   org_name
#   org_domain
#   time_zone
#

%define clockcfg        %{_sysconfdir}/sysconfig/clock
%define pkgdir          %{_datadir}/%{name}
%define sysrotconf      %{_sysconfdir}/logrotate.d/syslog
%define ntpconf         %{_sysconfdir}/ntp.conf
%define bashrcdir       %{pkgdir}/bashrc
%define localtime       %{_sysconfdir}/localtime

Name:               %{org_id}-system
Version:            %(echo %{gitrev} | tr - .)
Release:            1.%{osname}%{osrel}
Summary:            %{org_name} Basic System Setup
Group:              System/Setup
License:            Apache-2.0
Distribution:       %{org_name} Server Setup
Source0:            source.zip
BuildRoot:          %{_tmppath}/%{name}-root
Buildarch:          noarch
URL:                http://%{org_domain}/

# Handy packages
Requires:           bash
Requires:           bash-doc
Requires:           bc
Requires:           bind-utils
Requires:           ca-certificates-cacert
Requires:           ca-certificates-mozilla
Requires:           cpio
Requires:           diffutils
Requires:           ethtool
Requires:           expat
Requires:           iputils
Requires:           java-ca-certificates
Requires:           lsof
Requires:           mailx
Requires:           man
Requires:           man-pages
Requires:           net-tools
Requires:           ntp
Requires:           openssl
Requires:           patch
Requires:           patchutils
Requires:           procinfo
Requires:           psmisc
Requires:           ptools
Requires:           rpm
Requires:           screen
Requires:           socat
Requires:           strace
Requires:           sudo
Requires:           sysfsutils
Requires:           syslog-ng
Requires(post):     syslog-service
Requires:           sysstat
Requires:           tcpdump
Requires:           telnet
Requires:           traceroute
Requires:           tree
Requires:           update-alternatives
Requires:           vim
Requires:           vim-data
Requires:           wget
Requires:           xmlstarlet
Requires:           zip

# Scripts we use
Requires(post):     %{org_id}-rpm-scripts

%description
%{summary}.

%prep
%setup -c

sed -r \
  -e 's|@datadir@|%{_datadir}|g' \
  -e 's|@org_id@|%{org_id}|g' \
  -e 's|@org_name@|%{org_name}|g' \
  -e 's|@org_domain@|%{org_domain}|g' \
  < etc/bash.bashrc.local.in > bash.bashrc.local

%build

%install
install -m 0755 -d ${RPM_BUILD_ROOT}%{_sysconfdir}
install -m 0644 bash.bashrc.local ${RPM_BUILD_ROOT}%{_sysconfdir}/
install -m 0644 /dev/null ${RPM_BUILD_ROOT}%{_sysconfdir}/bash_completion
install -m 0755 -d ${RPM_BUILD_ROOT}%{bashrcdir}

%post

# Read scripts
. %{_datadir}/%{org_id}-rpm-scripts/rpm-scripts '%{name}' '%{version}' '%{release}'

# Configure ntp.conf
update_blurb %{ntpconf} << 'xxEOFxx'
restrict default ignore
restrict -6 default ignore

server      time1.google.com
restrict    time1.google.com nomodify notrap nopeer noquery
server      time2.google.com
restrict    time2.google.com nomodify notrap nopeer noquery
server      time3.google.com
restrict    time3.google.com nomodify notrap nopeer noquery
server      time4.google.com
restrict    time4.google.com nomodify notrap nopeer noquery

restrict 127.0.0.1
restrict -6 ::1
xxEOFxx

touch /var/log/messages /var/log/warn
chmod 644 /var/log/messages /var/log/warn

# Set time zone
if [ -e %{clockcfg} ]; then
	filevar_set_var %{clockcfg} TIMEZONE '%{time_zone}'
	filevar_set_var %{clockcfg} DEFAULT_TIMEZONE '%{time_zone}'
fi
rm -f %{localtime}
ln -sf %{_datadir}/zoneinfo/%{time_zone} %{localtime}

# Enable and restart ntp
. /etc/os-release
NTPSERVICE="ntpd.service"
if [ "${VERSION_ID}" = '13.1' ]; then
    NTPSERVICE="ntp.service"
fi
systemctl enable "${NTPSERVICE}"
systemctl restart "${NTPSERVICE}"

# Configure syslog rotation to relax file permissions
if [ -e %{sysrotconf} ]; then
	sed_patch_file %{sysrotconf} -r 's/^(.* create )640( .*)$/\1644\2/g'
fi

%files
%attr(644,root,root) %{_sysconfdir}/bash.bashrc.local
%attr(644,root,root) %{_sysconfdir}/bash_completion
%defattr(644,root,root,755)
%{bashrcdir}

