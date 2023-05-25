#!/bin/bash
(set -e && git submodule init && git submodule update) && echo "Dependencies installed" && \
( mkdir /gentle/ext/kaldi/tools/python && touch /gentle/ext/kaldi/tools/python/.use_default_python) && echo "Setting default path for python" && \
(./install_models.sh) && echo "Models installed" && \
(cd ext/kaldi/tools && extras/install_mkl.sh && ./extras/check_dependencies.sh && make && make clean) && echo "Kaldi tools installed" && \
(cd ext/kaldi/src && ./configure --static --static-math=yes --static-fst=yes --use-cuda=no && make depend && make && make clean) && echo "Kaldi src installed" && \
( cd /gentle && python3 setup.py develop)
(cd ext && make depend && make)
