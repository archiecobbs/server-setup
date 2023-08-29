
#
# Requires:
#   scm_revision
#   osname
#   osrel
#   org_id
#   org_name
#   org_domain
#   time_zone
#

%define clockcfg    %{_sysconfdir}/sysconfig/clock
%define pkgdir      %{_datadir}/%{name}
%define sysrotconf  %{_sysconfdir}/logrotate.d/syslog
%define ntpconf     %{_sysconfdir}/ntp.conf
%define bashrcdir   %{pkgdir}/bashrc
%define localtime   %{_sysconfdir}/localtime
%define dhcpconf    %{_sysconfdir}/sysconfig/network/dhcp
%define jourconf    %{_sysconfdir}/systemd/journald.conf
%define services    ntpd systemd-journald sysstat
%define zyppconf    %{_sysconfdir}/zypp/zypp.conf
%define unservices  postfix

%define roothome    /root
%define rootfwd     %{roothome}/.forward
%define rootvimrc   %{roothome}/.vimrc
%define rootemail   root@%{org_domain}

Name:               %{org_id}-system
Version:            %(echo %{scm_revision} | tr - .)
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
Requires:           cpio
Requires:           diffutils
Requires:           ethtool
Requires:           expat
Requires:           iotop
Requires:           iputils
Requires(post):     libzypp
Requires:           lsof
Requires:           mailx
Requires:           man
Requires:           man-pages
Requires:           net-tools
Requires:           net-tools-deprecated
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
Requires(post):     sysstat
Requires(post):     systemd
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
Obsoletes:          rsyslog

# %{org_id} stuff
Requires:           %{org_id}-sshd
Requires:           %{org_id}-zypper-repos

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
install -m 0755 -d %{buildroot}%{_sysconfdir}
install -m 0644 bash.bashrc.local %{buildroot}%{_sysconfdir}/
install -m 0644 /dev/null %{buildroot}%{_sysconfdir}/bash_completion
install -m 0755 -d %{buildroot}%{bashrcdir}

# Root's .forward file
install -d -m 0755 %{buildroot}%{roothome}
echo '%{rootemail}' > %{buildroot}%{rootfwd}

# Root's .vimrc file
cat > %{buildroot}%{rootvimrc} << xxEOFxx
se sw=4 ts=4 expandtab
xxEOFxx

%post

# Read scripts
. %{_datadir}/%{org_id}-rpm-scripts/rpm-scripts '%{name}' '%{version}' '%{release}'

# Configure ntp.conf
update_blurb %{ntpconf} << 'xxEOFxx'
restrict default ignore
restrict -6 default ignore
restrict 127.0.0.1
restrict -6 ::1

server      time1.google.com iburst
restrict    time1.google.com nomodify notrap nopeer noquery
server      time2.google.com iburst
restrict    time2.google.com nomodify notrap nopeer noquery
server      time3.google.com iburst
restrict    time3.google.com nomodify notrap nopeer noquery
server      time4.google.com iburst
restrict    time4.google.com nomodify notrap nopeer noquery
xxEOFxx

# Make warn file readable by non-root
touch /var/log/messages /var/log/warn
chmod 644 /var/log/messages /var/log/warn

# Set time zone
if [ -e %{clockcfg} ]; then
	filevar_set_var %{clockcfg} TIMEZONE '%{time_zone}'
	filevar_set_var %{clockcfg} DEFAULT_TIMEZONE '%{time_zone}'
fi
rm -f %{localtime}
ln -sf %{_datadir}/zoneinfo/%{time_zone} %{localtime}

# Configure syslog rotation to relax file permissions
if [ -e %{sysrotconf} ]; then
	sed_patch_file %{sysrotconf} -r 's/^(.* create )640( .*)$/\1644\2/g'
fi

# Set hardware clock to GMT
if [ -f %{clockcfg} ]; then
    filevar_set_var %{clockcfg} HWCLOCK '-u'
fi

# Don't set hostname via DHCP
filevar_set_var %{dhcpconf} DHCLIENT_SET_HOSTNAME "no"

# Tweak journald.conf
update_blurb %{jourconf} << 'xxEOFxx'
Storage=persistent
Compress=yes
SystemMaxFileSize=10M
SystemMaxFiles=50
xxEOFxx

# Enable and start/restart services
for SERVICE in %{services}; do
    systemctl -q -f enable "${SERVICE}".service
    if systemctl -q is-active "${SERVICE}".service; then
        systemctl reload-or-try-restart "${SERVICE}".service
    else
        systemctl start "${SERVICE}".service
    fi
done

# Disable postfix if installed
for SERVICE in %{unservices}; do
    systemctl -q disable "${SERVICE}".service >/dev/null 2>&1 || :
    systemctl -q stop "${SERVICE}".service >/dev/null 2>&1 || :
done

# Tweak zypp.conf
update_blurb %{zyppconf} << 'xxEOFxx'
solver.onlyRequires = true
download.use_deltarpm = false
xxEOFxx

%files
%attr(644,root,root) %{_sysconfdir}/bash.bashrc.local
%attr(644,root,root) %{_sysconfdir}/bash_completion
%defattr(644,root,root,755)
%{bashrcdir}
%{rootfwd}
%{rootvimrc}
