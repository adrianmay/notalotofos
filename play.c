#include "stdio.h"
int doSomethingInC(int a, int b, int * p) {
	*p = a+b;
	return a*b;
}
