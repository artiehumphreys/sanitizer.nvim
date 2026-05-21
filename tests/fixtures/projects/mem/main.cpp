#include <cstring>
#include <iostream>

int main() {
  int uninit;
  if (uninit)
    std::cout << "branch taken\n";
  return 0;
}
