#include <stdlib.h>

int main() {
  char *volatile buf = (char *)malloc(64);
  (void)buf;
  return 0;
}
