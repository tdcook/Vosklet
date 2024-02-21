#include "recognizer.h" 

recognizer::recognizer(model* mdl, float sampleRate, int index) : index(index) {
  auto main{[this, mdl, sampleRate](){
    rec = vosk_recognizer_new(mdl->mdl,sampleRate);
    finishConstruction();
  }};
  tryStealMdlThrd(main, mdl);
}
recognizer::recognizer(model* mdl, spkModel* spkMdl, float sampleRate, int index) {
  auto main{[this, mdl, sampleRate, spkMdl](){
    rec = vosk_recognizer_new_spk(mdl->mdl, sampleRate, spkMdl->mdl);
    finishConstruction();
  }};
  tryStealMdlThrd(main, mdl);
}
recognizer::recognizer(model* mdl, const std::string& grm, float sampleRate, int index, int dummy) {
  auto main{[this, mdl, sampleRate, grm](){
    rec = vosk_recognizer_new_grm(mdl->mdl, sampleRate, grm.c_str());
    finishConstruction();
  }};
  tryStealMdlThrd(main, mdl);
}
recognizer::~recognizer() {
  done.test_and_set(std::memory_order_relaxed);
  done.notify_one();
  controller.test_and_set(std::memory_order_relaxed);
  controller.notify_one();
  vosk_recognizer_free(rec);
  free(dataPtr);
}
void recognizer::tryStealMdlThrd(std::function<void()>&& main, model* mdl) {
  if(mdl->recognizerUsedThrd) {
    mdl->thrd.addTask(std::move(main));
    mdl->recognizerUsedThrd = true;
    return;
  }
  std::thread t{main};
  t.detach();
}
void recognizer::finishConstruction() {
  if(rec == nullptr) {
    fireEv("_continue", "Unable to initialize recognizer", this->index);
    return;
  }
  fireEv("_continue", nullptr, this->index);
  while(!done.test(std::memory_order_relaxed)) {
    controller.wait(!done.test(std::memory_order_relaxed), std::memory_order_relaxed);
    controller.clear(std::memory_order_relaxed);
    if(done.test(std::memory_order_relaxed)) continue;
    switch(vosk_recognizer_accept_waveform_f(rec, dataPtr, 512)) {
      case 0:
        fireEv("result", vosk_recognizer_result(rec), this->index);
        break;
      case 1:
        fireEv("partialResult", vosk_recognizer_partial_result(rec), this->index);
    }
  }
}
void recognizer::acceptWaveForm() {
  controller.test_and_set(std::memory_order_relaxed);
  controller.notify_one();
}
void recognizer::setGrm(const std::string& grm) {
  vosk_recognizer_set_grm(rec, grm.c_str());
}
void recognizer::setSpkModel(spkModel* mdl) {
  vosk_recognizer_set_spk_model(rec, mdl->mdl);
}
void recognizer::setWords(bool words) {
  vosk_recognizer_set_words(rec,words);
}
void recognizer::setPartialWords(bool partialWords) {
  vosk_recognizer_set_partial_words(rec, partialWords);
}
void recognizer::setNLSML(bool nlsml) {
  vosk_recognizer_set_nlsml(rec, nlsml);
}
void recognizer::setMaxAlternatives(int alts) {
  vosk_recognizer_set_max_alternatives(rec, alts);
}