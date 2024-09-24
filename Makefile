SOURCES = src/microCamlTypes.ml src/tokenTypes.ml src/lexer.mli src/lexer.ml src/utils.ml src/parser.mli src/parser.ml src/infer.ml main.ml

all: infer

clean:
	rm -f infer
	for X in ./ ./src; do \
      for Y in cmo cmi output; do \
        rm -f $$X/*.$$Y; \
      done; \
    done

infer: $(SOURCES)
	ocamlc -o infer -g -I src/ -I +str str.cma $(SOURCES)
