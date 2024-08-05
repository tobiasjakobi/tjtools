// SPDX-License-Identifier: GPL-2.0

#include <iostream>
#include <string>
#include <sstream>
#include <cassert>

using namespace std;

bool is_valid(string::const_iterator pos) {
  switch (*pos) {
  case '0':
  case '1':
  case '2':
  case '3':
  case '4':
  case '5':
  case '6':
  case '7':
  case '8':
  case '9':
  case 'A':
  case 'B':
  case 'C':
  case 'D':
  case 'E':
  case 'F':
    return true;
    break;

  default:
    return false;
    break;
  }
}

bool parse(string::const_iterator& pos, const string::const_iterator end, char& out) {
  assert(*pos == '%');

  string::const_iterator p = pos;
  string encoded;

  for (unsigned i = 0; i < 2; ++i) {
    p++;
    if (p == end || !is_valid(p))
      return true;

    encoded.push_back(*p);
  }

  stringstream decoder;
  unsigned k;

  decoder << hex << encoded;
  decoder >> k;

  if (k >= 256)
    return true;

  out = char(k);
  pos = p;

  return false;
}

int main([[maybe_unused]] int argc, [[maybe_unused]] char* argv[]) {
  string line, line_out;

  while (true) {
    getline(cin, line);
    line_out.clear();

    if (!cin)
      break;

    for (string::const_iterator i = line.begin(); i != line.end(); ++i) {
      char c;

      if (*i != '%')
        c = *i;
      else if (parse(i, line.end(), c))
        continue;

      line_out.push_back(c);
    }

    cout << line_out << endl;
  }

  return 0;
}
