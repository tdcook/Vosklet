FROM docker.io/emscripten/emsdk:4.0.7
WORKDIR /var/build

ARG SHARED_FLAGS="-g0 -O3 -flto -msimd128 -matomics -mreference-types \
    -mextended-const -msign-ext -mmutable-globals -w"

RUN apt-get update && apt-get install -y autoconf libtool gcc-multilib

RUN curl -O https://www.openfst.org/twiki/pub/FST/FstDownload/openfst-1.8.4.tar.gz \
    && tar xvf openfst-1.8.4.tar.gz --no-same-owner \
    && cd /var/build/openfst-1.8.4 && autoreconf -is \
    && CXXFLAGS="$SHARED_FLAGS -fno-rtti -w" emconfigure ./configure \
    --prefix=/var/build/openfst --enable-static --disable-shared --enable-ngram-fsts \
    --disable-bin && emmake make -j`$(nproc)` install

COPY src/OpenBLAS.patch /var/build/OpenBLAS.patch
ARG OPENBLAS_FLAGS="CC=emcc HOSTCC=gcc TARGET=RISCV64_GENERIC USE_THREAD=0 NO_SHARED=1 \
    NOFORTRAN=1 BINARY=32 BUILD_SINGLE=1 BUILD_DOUBLE=1 BUILD_BFLOAT16=0 \
    BUILD_COMPLEX16=0 BUILD_COMPLEX=0"
ARG OPENBLAS_CFLAGS="$SHARED_FLAGS -fno-exceptions -fno-rtti"

RUN git clone -b v0.3.29 --depth 1 https://github.com/OpenMathLib/OpenBLAS /var/build/openblas \
    && cd /var/build/openblas \
    && git apply /var/build/OpenBLAS.patch \
    && make -j`$(nproc)` $OPENBLAS_FLAGS CFLAGS="$OPENBLAS_CFLAGS" PREFIX=/var/build/openblas > /dev/null \
    && make $OPENBLAS_FLAGS CFLAGS="$OPENBLAS_CFLAGS" PREFIX=/var/build/openblas install

RUN git clone --depth=1 https://github.com/kaldi-asr/kaldi /var/build/kaldi \
    && cd /var/build/kaldi/src \
    && CXXFLAGS="$SHARED_FLAGS -UHAVE_EXECINFO_H -DEMSCRIPTEN_HAS_UNBOUND_TYPE_NAMES=0 -fwasm-exceptions -g0" LDFLAGS="-lembind" \
    emconfigure ./configure \
    --use-cuda=no --with-cudadecoder=no --static --static-math --static-fst \
    --fst-version=1.8.4 --debug-level=0 --fst-root=/var/build/openfst \
    --openblas-root=/var/build/openblas --host=WASM \
    && emmake make -j`$(nproc)` online2 rnnlm

COPY src/Vosk.patch /var/build/Vosk.patch
ARG VOSK_OBJFILES="recognizer.o language_model.o model.o spk_model.o vosk_api.o"
ARG VOSK_CFILES="recognizer.cc language_model.cc model.cc spk_model.cc vosk_api.cc"

RUN git clone -b v0.3.50 --depth=1 https://github.com/alphacep/vosk-api /var/build/vosk \
    && cd /var/build/vosk/src \
    && git apply /var/build/Vosk.patch \
    && em++ $SHARED_FLAGS -DOPENFST_VER=10804 -fwasm-exceptions -I. -I/var/build/kaldi/src \
    -I/var/build/openfst/include $VOSK_CFILES -c \
    && emar -rcs vosk.a $VOSK_OBJFILES

ENV VOSKLET_OBJFILES="/var/build/tmp/Util.o /var/build/tmp/CommonModel.o /var/build/tmp/Recognizer.o /var/build/tmp/Bindings.o"
ENV VOSKLET_CFILES="/var/build/src/Util.cc /var/build/src/CommonModel.cc /var/build/src/Recognizer.cc /var/build/src/Bindings.cc"
ENV VOSKLET_FLAGS="$SHARED_FLAGS -fno-rtti -sSTRICT -sWASM_WORKERS=2"

ENV INITIAL_MEMORY=315mb
ENV VOSKLET_LDFLAGS="-sWASMFS -sMODULARIZE -sTEXTDECODER=2 -sEVAL_CTORS=2 -sALLOW_UNIMPLEMENTED_SYSCALLS -sINITIAL_MEMORY=$INITIAL_MEMORY -sALLOW_MEMORY_GROWTH -sPOLYFILL=0 -sEXIT_RUNTIME=0 -sINVOKE_RUN=0 -sSUPPORT_LONGJMP=0 -sINCOMING_MODULE_JS_API=wasmMemory,instantiateWasm,wasm -sEXPORT_NAME=loadVosklet -sMALLOC=emmalloc -sENVIRONMENT=web,worker -L/var/build/kaldi/src -l:online2/kaldi-online2.a -l:decoder/kaldi-decoder.a -l:ivector/kaldi-ivector.a -l:gmm/kaldi-gmm.a -l:tree/kaldi-tree.a -l:feat/kaldi-feat.a -l:cudamatrix/kaldi-cudamatrix.a -l:lat/kaldi-lat.a -l:lm/kaldi-lm.a -l:rnnlm/kaldi-rnnlm.a -l:hmm/kaldi-hmm.a -l:nnet3/kaldi-nnet3.a -l:transform/kaldi-transform.a -l:matrix/kaldi-matrix.a -l:fstext/kaldi-fstext.a -l:util/kaldi-util.a -l:base/kaldi-base.a -L/var/build/openfst/lib -l:libfst.a -l:libfstngram.a -L/var/build/openblas -l:lib/libopenblas.a -L/var/build/vosk/src -l:vosk.a -lembind --no-entry --closure 1 --pre-js"

ENV MAX_THREADS=1

RUN mkdir /var/build/dest /var/build/tmp
VOLUME /var/build/dest

ENTRYPOINT ["/bin/sh","-c"]
CMD ["cd /var/build/tmp && em++ $VOSKLET_CFILES $VOSKLET_FLAGS -DEMSCRIPTEN_HAS_UNBOUND_TYPE_NAMES=0 -DMAX_WORKERS=$MAX_THREADS -fno-exceptions -std=c++23 -c -I/var/build/src -I/var/build/vosk/src && em++ $VOSKLET_OBJFILES $VOSKLET_FLAGS $VOSKLET_LDFLAGS /var/build/src/Wrapper.js -o /tmp/Vosklet.js && cp /tmp/Vosklet.js /var/build/dest/Vosklet.js"]
