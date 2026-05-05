#include <iostream>

int main() {
  int *ptr = new int(10);
  delete ptr;

  std::cout << *ptr << '\n';
  return 0;
}
