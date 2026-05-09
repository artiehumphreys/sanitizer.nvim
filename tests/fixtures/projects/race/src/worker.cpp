#include "worker.hpp"
#include <cstddef>

static int i = 0;

void increment_worker(std::size_t iterations) {
  for (std::size_t j = 0; j < iterations; ++j) {
    i++;
  }
}

void decrement_worker(std::size_t iterations) {
  for (std::size_t k = 0; k < iterations; ++k) {
    i--;
  }
}
