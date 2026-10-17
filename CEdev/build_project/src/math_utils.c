#include <tice.h>
#include <ti/screen.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <keypadc.h>
#include <math.h>

#ifndef RAND_MAX
#define RAND_MAX 32767
#endif

int math_utils_add(int a, int b) {
    return a + b;
}

int math_utils_multiply(int a, int b) {
    return a * b;
}
