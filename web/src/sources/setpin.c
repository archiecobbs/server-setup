
#include <sys/types.h>

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pwd.h>
#include <err.h>

static void usage(void);

int
main(int argc, char **argv)
{
    struct passwd *pwd;
    const char *username;
    const char *pin = NULL;
    const uid_t uid = getuid();
    int i;

    // Parse command line
    username = getenv("USER");
    while ((i = getopt(argc, argv, "u:")) != -1) {
        switch (i) {
        case 'u':
            username = optarg;
            break;
        case '?':
        default:
            usage();
            exit(1);
        }
    }
    argv += optind;
    argc -= optind;
    switch (argc) {
    case 0:
        break;
    case 1:
        pin = argv[0];
        break;
    default:
        usage();
        exit(1);
    }

    // Validate user
    if (uid != 0) {
        if ((pwd = getpwnam(username)) == NULL)
            errx(1, "user `%s' not found", username);
        if (uid != pwd->pw_uid)
            errx(1, "you must be root to change another user's PIN");
    }
    if (pin != NULL)
        execl("/usr/bin/htpasswd2", "htpasswd2", "-msb", OTP_PIN_FILE, username, pin, NULL);
    else
        execl("/usr/bin/htpasswd2", "htpasswd2", "-ms", OTP_PIN_FILE, username, NULL);
    err(1, "execve");
}

static void
usage(void)
{
    fprintf(stderr, "Usage: setpin [-u username] [pin]\n");
}

