The purpose of this RPM is to set up SMTP mail routing for one or more
email domains. The daemon used is exim(8).

This RPM does NOT create actual mailboxes; it only knows how to route
via SMTP. It is expected that users already have an email account where
they want all their email to go.

For example, Fred might normally use fred@gmail.com, but he also wants
to use fred@company1.com and fred@company2.com. Fred can configure this
RPM to be an SMTP router for company1.com and company2.com and forward
all his email from those domains to fred@gmail.com.

Note that besides setting up this router, Fred would also need to:

    o Purchase SSL key/certificate for "company1.com" and put it in src/tls
    o Configure the DNS for "company1.com" and "company2.com":
        o MX entry pointing to the server running this RPM
        o SPF entry with "mx" and "include:_spf.google.com"
    o Add fred@company1.com and fred@company2.com to his GMail accounts

This RPM supports multiple domains, aliases, and mailing lists.

TODO:
   - Add DKIM signatures; see http://mikepultz.com/2010/02/using-dkim-in-exim/
