#include "genericModel.h"
#include "recognizer.h"

#include <emscripten/bind.h>
using namespace emscripten;

EMSCRIPTEN_BINDINGS() {
  function("setLogLevel", &vosk_set_log_level, allow_raw_pointers());
  class_<genericModel>("genericModel")
  .constructor<int, bool, std::string, std::string>(allow_raw_pointers())
  .function("extractAndLoad", &genericModel::extractAndLoad, allow_raw_pointers());
  
  class_<recognizer>("recognizer") 
  .constructor<int, float, genericModel*>(allow_raw_pointers())
  .constructor<int, float, genericModel*, genericModel*>(allow_raw_pointers())
  .constructor<int, float, genericModel*, std::string, int>(allow_raw_pointers())
  .function("setWords", &recognizer::setWords, allow_raw_pointers())
  .function("setPartialWords", &recognizer::setPartialWords, allow_raw_pointers())
  .function("setGrm", &recognizer::setGrm, allow_raw_pointers())
  .function("setNLSML", &recognizer::setNLSML, allow_raw_pointers())
  .function("setSpkModel", &recognizer::setSpkModel, allow_raw_pointers())
  .function("setMaxAlternatives", &recognizer::setMaxAlternatives, allow_raw_pointers())
  .function("acceptWaveForm", &recognizer::acceptWaveForm, allow_raw_pointers());
};