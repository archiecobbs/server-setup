#include <sys/types.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <pwd.h>
#include <err.h>

static void print_key(FILE *fp, const char *key, u_int len);
static void usage(void);

#define DEFAULT_COUNTER         0
#define DEFAULT_KEYLEN          16
#define DEFAULT_NUM_DIGITS      6
#define DEFAULT_INTERVAL        30
#define DEFAULT_NAME            "Security Token"

#define RANDOM_FILE             "/dev/urandom"

int
main(int argc, char **argv)
{
    const char *name = DEFAULT_NAME;
    unsigned int interval = DEFAULT_INTERVAL;
    unsigned int counter = DEFAULT_COUNTER;
    unsigned int num_digits = 6;
    int time_based = 1;
    int lock_down = 1;
    int hex_digits = 0;
    char *key = NULL;
    int keylen = DEFAULT_KEYLEN;
    FILE *fp;
    int i, j;
    unsigned int b;

    // Parse command line
    while ((i = getopt(argc, argv, "c:d:Ii:k:Nn:x")) != -1) {
        switch (i) {
        case 'c':
            counter = atoi(optarg);
            break;
        case 'd':
            num_digits = atoi(optarg);
            break;
        case 'I':
            time_based = 0;
            break;
        case 'i':
            interval = atoi(optarg);
            break;
        case 'k':
            if (strlen(optarg) % 2 != 0)
                errx(1, "invalid hex key `%s': odd number of digits", optarg);
            if ((key = malloc((keylen = strlen(optarg) / 2))) == NULL)
                err(1, "malloc");
            for (j = 0; j < keylen; j++) {
                if (sscanf(optarg + 2 * j, "%2x", &b) != 1)
                    errx(1, "invalid hex key `%s': can't parse", optarg);
                key[j] = b & 0xff;
            }
            break;
        case 'n':
            name = optarg;
            break;
        case 'N':
            lock_down = 0;
            break;
        case 'x':
            hex_digits = 1;
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
    default:
        usage();
        exit(1);
    }

    // Generate key
    if (key == NULL) {
        if ((key = malloc((keylen = DEFAULT_KEYLEN))) == NULL)
            err(1, "malloc");
        if ((fp = fopen(RANDOM_FILE, "r")) == NULL)
            err(1, "%s", RANDOM_FILE);
        if (fread(key, 1, keylen, fp) != keylen)
            err(1, "%s", RANDOM_FILE);
        fclose(fp);
        fprintf(stderr, "generated key: ");
        print_key(stderr, key, keylen);
        fprintf(stderr, "\n");
    }

    // Output URL
    printf("oathtoken:///addToken?name=");
    for (i = 0; name[i] != '\0'; i++) {
        if (isalnum(name[i]))
            printf("%c", name[i]);
        else
            printf("%%%02x", name[i] & 0xff);
    }
    printf("&key=");
    print_key(stdout, key, keylen);
    if (time_based)
        printf("&timeBased=true");
    if (!time_based && counter != DEFAULT_COUNTER)
        printf("&counter=%u", counter);
    if (time_based && interval != DEFAULT_INTERVAL)
        printf("&interval=%u", interval);
    if (num_digits != DEFAULT_NUM_DIGITS)
        printf("&numDigits=%u", num_digits);
    if (hex_digits)
        printf("&displayHex=true");
    if (lock_down)
        printf("&lockdown=true");
    printf("\n");

    // Done
    return 0;
}

static void
print_key(FILE *fp, const char *key, u_int len)
{
    int i;

    for (i = 0; i < len; i++)
        fprintf(fp, "%02x", key[i] & 0xff);
}

static void
usage(void)
{
    fprintf(stderr, "Usage: genotpurl [-INx] [-n name] [-c counter] [-d num-digits] [-i interval] [-k key]\n");
    fprintf(stderr, "Options:\n");
    fprintf(stderr, "  -c\tInitial counter value (default %d)\n", DEFAULT_COUNTER);
    fprintf(stderr, "  -d\tNumber of digits (default %d)\n", DEFAULT_NUM_DIGITS);
    fprintf(stderr, "  -I\tInterval-based instead of time-based\n");
    fprintf(stderr, "  -i\tTime interval in seconds (default %d)\n", DEFAULT_INTERVAL);
    fprintf(stderr, "  -k\tSpecify hex key (otherwise, auto-generate)\n");
    fprintf(stderr, "  -N\tDon't lock down\n");
    fprintf(stderr, "  -n\tSpecify name for token (default \"%s\")\n", DEFAULT_NAME);
    fprintf(stderr, "  -x\tHex digits instead of decimal\n");
}
