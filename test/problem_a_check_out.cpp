#include <iostream>
#include <string>
#include <vector>
#include <cctype>
std::vector<size_t> parseShynessesVector(std::string input)
{
  std::vector<size_t> res;
  for (char &c : input)
  {
    if(isdigit(c))
    {
      res.push_back(c - '0');
    }
  }
  return res;
}
std::string solveShynessProblem(std::vector<size_t> shy_vt, size_t test_no)
{
  std::string out("Case #");
  out.append(std::to_string(test_no));
  out.append(" : ");
  size_t numToAdd(0);
  size_t curNumClapping(0);
  for (size_t shynessIndex(0);
    shynessIndex<shy_vt.size();
    ++shynessIndex)
  {
    if(shy_vt [ shynessIndex ]> 0)
    {
      // may not be required since never ends on 0
      while (shynessIndex > curNumClapping)
      {
        ++numToAdd;
        ++curNumClapping;
      }
      curNumClapping += shy_vt [ shynessIndex ];
    }
  }
  out.append(std::to_string(numToAdd));
  return out;
}
int main()
{
  std::string numTestsStr;
  size_t numTests;
  std::getline(std::cin, numTestsStr);
  numTests = stoi(numTestsStr);
  std::string curInput;
  size_t indexOfSpace;
  size_t maxShyness;
  std::string shynessStr;
  std::vector<size_t> shynesses;
  for (size_t tests = 0;
    tests < numTests;
    ++tests)
  {
    std::getline(std::cin, curInput);
    bool logical = false;
    if(logical == true)
    {
      std::cout << "wow!" << std::endl;
    }
    if(logical != false)
    {
      std::cout << "huh!" << std::endl;
    }
    /*
    test multi - line commment
    */
    indexOfSpace = curInput.find(' ');
    // asdf
    std::string intermediateStr = curInput.substr(0, indexOfSpace);
    maxShyness = stoi(intermediateStr);
    shynessStr = curInput.substr(indexOfSpace + 1);
    a = b ? c : d;
    shynesses = parseShynessesVector(shynessStr);
    std::cout << solveShynessProblem(shynesses, tests + 1) << std::endl;
  }
}
