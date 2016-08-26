/* $Id: base32.h 5403 2016-08-26 18:34:09Z archie $ */

#include <sys/types.h>

extern void base32_encode(const unsigned char *plain, size_t len, unsigned char *coded);
extern size_t base32_decode(const unsigned char *coded, unsigned char *plain);
