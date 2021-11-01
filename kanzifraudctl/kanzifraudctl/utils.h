//
//  utils.h
//  kanzifraudctl
//
//  Created by noone on 9/28/20.
//  Copyright © 2020 noone. All rights reserved.
//

#ifndef utils_h
#define utils_h

#include <stdio.h>

long str2hex(unsigned long long max, unsigned char *buf, const char *str);
unsigned char * base64_encode(const unsigned char *src, size_t len, size_t *out_len);


#endif /* utils_h */
