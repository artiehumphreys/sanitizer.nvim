#include <cstdlib>
#include <iostream>
#include <limits>
#include <string>

int main() {
  std::string M = std::to_string(std::numeric_limits<int>::max());
  // stoi is a runtime value
  int x = std::stoi(M);
  x += 1;
  std::cout << x << '\n';
}
