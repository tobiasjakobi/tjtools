// SPDX-License-Identifier: GPL-2.0

#include <iostream>
#include <string>

int main([[maybe_unused]] int argc, [[maybe_unused]] char* argv[]) {
  std::string line, line_out;
  bool line_begin, word_begin;

  while (true) {
    std::getline(std::cin, line);

    if (!std::cin)
      break;

    line_begin = true;
    word_begin = false;
    line_out.clear();

    for (auto i = line.cbegin(); i != line.cend(); ++i) {
      if (line_begin) {
        line_out.push_back(*i);
        line_begin = false;
        continue;
      }

      if (*i == ' ' || *i == '\t') {
        word_begin = true;
        line_out.push_back(*i);
        continue;
      }

      if (word_begin) {
        line_out.push_back(*i);
        if (isalpha(*i))
          word_begin = false;
        continue;
      }

      if (isupper(*i))
        line_out.push_back(tolower(*i));
      else
        line_out.push_back(*i);
    }

    std::cout << line_out << std::endl;
  }

  return 0;
}
