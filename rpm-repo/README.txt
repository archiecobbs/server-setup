This RPM sets up an RPM repository for use with zypper(8).

To use, build it and install the "ORGNAME-rpm-repo" RPM on the server
that will host the RPM repository.

Then install the "ORGNAME-zypper-repos" on the client machines that will pull
from the repository. Assuming ORGNAME-web is also installed on the server machine,
the client machines should then be able to pull RPMs down.

Finally, use "ant publish" to publish any RPMs to the repository. The current
user doing this must be in the 'rpmrepo' UNIX group.
