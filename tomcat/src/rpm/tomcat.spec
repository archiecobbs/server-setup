
#
# Requires:
#   scm_revision
#   osname
#   osrel
#   org_id
#   org_name
#   org_domain
#   tomcat_port80_mappings
#   tomcat_port443_mappings
#

%define pkgdir      %{_datadir}/%{name}

%define tomcatver   9.0.43

%define pkgdir      %{_datadir}/%{name}
%define catoptsdir  %{pkgdir}/catalina.opts.d
%define tomconfdir  %{_sysconfdir}/tomcat/conf.d
%define serverxml   %{_sysconfdir}/tomcat/server.xml
%define contextxml  %{_sysconfdir}/tomcat/context.xml
%define tomcatconf  %{_sysconfdir}/tomcat/tomcat.conf
%define logrotated  %{_sysconfdir}/logrotate.d
%define maxheap     4g

# RPM config file include directory
%define servincdir  %{_datadir}/%{org_id}-web/apache

Name:               %{org_id}-tomcat
Version:            %(echo %{scm_revision} | tr - .)
Release:            1.%{osname}%{osrel}
Summary:            %{org_name} Setup for Tomcat (%{osname}%{osrel})
License:            Apache-2.0
Distribution:       %{org_name} Server Setup
Source:             source.zip
BuildRoot:          %{_tmppath}/%{name}-root
Buildarch:          noarch
URL:                http://%{org_domain}/
Requires(post):     %{org_id}-rpm-scripts
Requires:           tomcat >= %{tomcatver}
Requires(post):     tomcat >= %{tomcatver}
Requires:           logrotate
Requires:           libtcnative-1-0

%description
%{summary}.

%clean
rm -rf %{buildroot}

%prep
rm -rf %{buildroot}
%setup -c

%build

genproxy()
{
    MAPPINGS="$1"
    echo 'RewriteEngine on'
    echo ${MAPPINGS} | tr , '\n' | while read MAPPING; do
        MAPPING=`echo "${MAPPING}" | sed -r 's|^:||g'`
        if [ -z "${MAPPING}" ]; then
            continue
        fi
        APATH=`echo "${MAPPING}" | sed -rn 's@^((/[^:/]+)+):((/[^:/]+)+|/)$@\1@gp'`
        TPATH=`echo "${MAPPING}" | sed -rn 's@^((/[^:/]+)+):((/[^:/]+)+|/)$@\3@gp'`
        TPATH2="${TPATH}"
        if [ "${TPATH}" = '/' ]; then
            TPATH2=""
        fi
        if [ -z "${APATH}" -o -z "${TPATH}" ]; then
            echo "*** Error: invalid mapping: ${MAPPING}" 1>&2
            exit 1
        fi
        cat << xxEOFxx
RewriteRule ^${APATH}$ ${APATH}/ [redirect=permanent,last]
RewriteRule ^${APATH}/(.*)$ http://127.0.0.1:8080${TPATH2}/\$1 [proxy,last]
<Location "${APATH}/">
    ProxyPassReverse             http://127.0.0.1:8080${TPATH2}/
    ProxyPassReverseCookiePath   ${TPATH} ${APATH}/
</Location>
xxEOFxx
    done
}

# Generate include files
printf '# Port 80 mappings for Tomcat\n' >> %{name}.port80.include
genproxy '%{tomcat_port80_mappings}' >> %{name}.port80.include
printf '# Port 443 mappings for Tomcat\n' > %{name}.port443.include
genproxy '%{tomcat_port443_mappings}' >> %{name}.port443.include

# Customizations to tomcat.conf
cat > %{org_id}-tomcat.conf << 'xxEOFxx'

# Set various Java runtime properties from config files
CATALINA_OPTS="`find %{catoptsdir} -maxdepth 1 -type f -print0 | sort -z | xargs -0 cat | tr \\\\n ' '`"

# Clear work directory on restart
CLEAR_WORK="true"
xxEOFxx

%install

# Customizations to tomcat.conf
install -d %{buildroot}%{tomconfdir}
install %{org_id}-tomcat.conf %{buildroot}%{tomconfdir}/

# Add missing logrotate configuration /var/log/tomcat/access_log
install -d %{buildroot}%{logrotated}
install logrotate/tomcat-access-log %{buildroot}%{logrotated}/

# Install fixup XSL transforms
install -d %{buildroot}%{pkgdir}/xsl
install xsl/* %{buildroot}%{pkgdir}/xsl/

# Directory for CATALINA_OPTS tweaks
install -d %{buildroot}%{catoptsdir}

# Configure max heap
printf -- '-Xmx%{maxheap}\n' > %{buildroot}%{catoptsdir}/00-maxheap.opts

# Dump heap on OOM
printf -- '-XX:-HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/var/log/tomcat/\n' > %{buildroot}%{catoptsdir}/00-heapdump.opts

# Stop stupid behavior
printf -- '-Dnet.sf.ehcache.skipUpdateCheck=true\n' > %{buildroot}%{catoptsdir}/00-ehcache-fix.opts

# Avoid AWT weirdness
printf -- '-Djava.awt.headless=true\n' > %{buildroot}%{catoptsdir}/00-awt-headless.opts

# Install Apache include files
install -d %{buildroot}%{servincdir}
install {,%{buildroot}%{servincdir}/}%{name}.port80.include
install {,%{buildroot}%{servincdir}/}%{name}.port443.include

%post

# Load handy functions
. %{_datadir}/%{org_id}-rpm-scripts/rpm-scripts '%{name}' '%{version}' '%{release}'

# Patch server.xml
xml_patch_file '%{serverxml}' '%{pkgdir}/xsl/server-patch.xsl'

# Patch context.xml
xml_patch_file '%{contextxml}' '%{pkgdir}/xsl/context-patch.xsl'

# Enable tomcat
systemctl -q enable tomcat.service

# Reload apache (if present)
if systemctl is-active apache2.service >/dev/null; then
    systemctl reload-or-try-restart apache2.service
fi

%files
%defattr(644,root,root,755)
%{servincdir}/*
%{tomconfdir}/*
%{logrotated}/*
%{pkgdir}
