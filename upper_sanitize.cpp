#include <iostream>
#include <string>

using namespace std;

int main(int argc, char* argv[]) {
  string line, line_out;
  bool line_begin, word_begin;

  while (true) {
    getline(cin, line);

    if (!cin)
      break;

    line_begin = true;
    word_begin = false;
    line_out.clear();

    for (string::const_iterator i = line.begin(); i != line.end(); ++i) {
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

    cout << line_out << endl;
  }

  return 0;
}
