OCAMLMAKEFILE=OCamlMakefile

SOURCES=oembed.mli oembed.ml
PACKS=extlib json-wheel netclient netstring str xml-light
RESULT=oembed

include $(OCAMLMAKEFILE)

all:    native-code-library byte-code-library

install:    libinstall

uninstall:  libuninstall

