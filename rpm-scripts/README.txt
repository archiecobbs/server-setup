This RPM installs a shell script defining various functions useful
inside RPM scriptlets.

See src/scripts/rpm-scripts.sh for what's available.

Example of using this RPM in another spec file:


    Requires(post):     %{org_id}-rpm-scripts

    ...

    # Read scripts
    . %{_datadir}/%{org_id}-rpm-scripts/rpm-scripts '%{name}' '%{version}' '%{release}'

    # Utilize various shell functions here...

