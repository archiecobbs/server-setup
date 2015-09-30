The purpose of this RPM is to set up and configure Tomcat.

    o Listen for connections only on localhost.
        o This assumes you are using Apache to reverse proxy to Tomcat
    o Don't reload on file changes
    o Don't persist sessions across restarts
    o Clear work directory on restart
    o Use up to 70% of system memory for the heap
