(rm ext/*.o)
(rm -rf ext/kaldi)
(rm -rf /var/lib/apt/lists/*)
(apt-get clean && apt-get autoclean && apt-get autoremove)