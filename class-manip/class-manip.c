#include <brl.mod/blitz.mod/blitz.h>

// Return a pointer to the bbObjectFree function
void* objFreePtr() {
	return &bbObjectFree;
}
