
#
# Requires:
#   gitrev
#   osname
#   osrel
#   org_id
#   org_name
#   org_domain
#   tomcat_port80_mappings
#   tomcat_port443_mappings
#

%define pkgdir      %{_datadir}/%{name}

%define tomcatver   7.0.55

%define pkgdir      %{_datadir}/%{name}
%define serverxml   %{_sysconfdir}/tomcat/server.xml
%define contextxml  %{_sysconfdir}/tomcat/context.xml
%define tomcatconf  %{_sysconfdir}/tomcat/tomcat.conf
%define tomcatsysd  %{_sbindir}/tomcat-sysd
%define heappct     70

# %{org_id}-web RPM config file include directory
%define servincdir  %{_datadir}/%{org_id}-web/apache

Name:               %{org_id}-tomcat
Version:            %(echo %{gitrev} | tr - .)
Release:            1.%{osname}%{osrel}
Summary:            %{org_name} Setup for Tomcat (%{osname}%{osrel})
License:            Apache-2.0
Distribution:       %{org_name} Server Setup
BuildRoot:          %{_tmppath}/%{name}-root
Buildarch:          noarch
URL:                http://%{org_domain}/
Requires(post):     %{org_id}-rpm-scripts
Requires:           tomcat >= %{tomcatver}
Requires:           libtcnative-1-0

%description
%{summary}.

%clean
rm -rf %{buildroot}

%build

genproxy()
{
    MAPPINGS="$1"
    echo ${MAPPINGS} | tr , '\n' | while read MAPPING; do
        MAPPING=`echo "${MAPPING}" | sed -r 's|^:||g'`
        if [ -z "${MAPPING}" ]; then
            continue
        fi
        APATH=`echo "${MAPPING}" | sed -rn 's|^((/[^:/]+)+):((/[^:/]+)+)$|\1|gp'`
        TPATH=`echo "${MAPPING}" | sed -rn 's|^((/[^:/]+)+):((/[^:/]+)+)$|\3|gp'`
        if [ -z "${APATH}" -o -z "${TPATH}" ]; then
            echo "*** Error: invalid mapping: ${MAPPING}" 1>&2
            exit 1
        fi
        cat << xxEOFxx
RewriteRule ^${APATH}$ ${APATH}/ [passthrough,last]
RewriteRule ^${APATH}/(.*)$ http://127.0.0.1:8080${TPATH}/\$1 [proxy,last]
<Location "${APATH}/">
    ProxyPassReverse             http://127.0.0.1:8080${TPATH}/
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

%install

install -d %{buildroot}%{servincdir}
install {,%{buildroot}%{servincdir}/}%{name}.port80.include
install {,%{buildroot}%{servincdir}/}%{name}.port443.include

%post

# Load handy functions
. %{_datadir}/%{org_id}-rpm-scripts/rpm-scripts '%{name}' '%{version}' '%{release}'

# Only listen on the loopback interface
sed_patch_file %{serverxml} -r 's|^([[:space:]]*)(<Connector)( port=".*$)|\1\2 address="127.0.0.1"\3|g'

# Use the NIO connector
sed_patch_file %{serverxml} -r 's|^(.*<Connector.*8080.*protocol=")[^"]+(".*$)|\1org.apache.coyote.http11.Http11NioProtocol\2|g'

# Don't reload on file changes
sed_patch_file %{contextxml} -r 's|^([[:space:]]+)(<WatchedResource.*)$|\1<!-- \2 -->|g'

# Don't persist sessions across restarts
sed_patch_file %{contextxml} -r 's|^([[:space:]]+)(<Manager +pathname="" */>)[[:space:]]*$|\1--> \2 <!--|g'

# Clear work directory on restart
filevar_set_var %{tomcatconf} CLEAR_WORK "true"

# Set various Java runtime properties
CATALINA_OPTS=""

# Calculate %{heappct}% of available memory
TOTAL_MEM=`free -b | sed -nr 's/^Mem:[[:space:]]*([0-9]+).*/\1/gp'`
HEAP_MEM=`expr \( "${TOTAL_MEM}" \* %{heappct} \) / 100`

# Configure max heap
CATALINA_OPTS="${CATALINA_OPTS} -Xmx${HEAP_MEM}"

# Avoid AWT weirdness
CATALINA_OPTS="${CATALINA_OPTS} -Djava.awt.headless=true"

# Apply properties
filevar_set_var %{tomcatconf} CATALINA_OPTS "${CATALINA_OPTS}"

# Ensure stdout/stderr ends up in catalina.out
if [ -f '%{tomcatsysd}' ]; then
    sed_patch_file %{tomcatsysd} -r 's|^( *org.apache.catalina.startup.Bootstrap start)$|\1 \\\
        >> ${CATALINA_BASE}/logs/catalina.out 2>\&1|g'
fi

# Enable tomcat
systemctl -q enable tomcat.service

# Reload apache (if present)
if systemctl is-active apache2.service >/dev/null; then
    systemctl reload-or-try-restart apache2.service
fi

%files
%attr(644,root,root) %{servincdir}/*
