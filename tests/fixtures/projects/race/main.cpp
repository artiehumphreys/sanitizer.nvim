#include "src/worker.hpp"
#include <thread>

int main() {
  std::size_t iterations = 1 << 10;
  std::thread t1(increment_worker, iterations);
  std::thread t2(decrement_worker, iterations);

  t1.join();
  t2.join();
}
