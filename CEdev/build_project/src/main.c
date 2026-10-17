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


static int y = 0;

static int product = 0;

static int sum_val = 0;

static int i = 0;

static int x = 0;


int multiply(int a, int b) {
    return a * b;
}

int main(void) {

    os_ClrHome();

    x = 10;

    y = 20;

    sum_val = x + y;

    printf("%d\n", (int)(sum_val)); ;

    product = multiply(4, 5);

    printf("%d\n", (int)(product)); ;

    if (sum_val > 15) {
        printf("%d\n", (int)(1)); ;
    } else {
        printf("%d\n", (int)(0)); ;
    }

    for (i = 0; i < 3; i++) {
        printf("%d\n", (int)(i)); ;
    }

    while (!os_GetCSC());

    return 0;

}