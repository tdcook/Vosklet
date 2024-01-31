#pragma once
#include "global.h"

#include <string>
#include <filesystem>
#include <fstream>

#include <fcntl.h>
#include <vosk_api.h>
#include <archive.h>
#include <archive_entry.h>
namespace fs = std::filesystem;

struct genericModel {
  const std::string storepath{};
  const std::string id{};
  int index{};
  static bool extractModel(const char* fileBuf, size_t size);
  virtual bool checkModelFiles() = 0;
  virtual void load(bool) = 0;
  bool checkModel();
  void afterFetch(int memAddr, size_t size);
  genericModel(const std::string &storepath, const std::string &id, int index);
};

