The purpose of this RPM is to automatically create and maintain user
accounts on Linux machines.

Pre-installed home directory files can be put in src/home/<username>
and will be automatically included with the account. A good example
would be .ssh/authorized_keys, because this RPM does not support normal
password authentication.

The accounts and their configurable privileges are configured in the
XML configuration file src/xml/accounts.xml.

Note: this RPM will not only create user accounts, but remove them as
well. Users maintained by this RPM are indicated by their membership in
the "_autousers", so don't add users to that group manually.

When an account is removed, any files in the user's home directory that
are not part of the RPM are left in place.
