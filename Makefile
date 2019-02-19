.PHONY: all
all: build-ml

.PHONY: build-ml
build-ml: src/uAX31.ml src/parserAutomaton.mly
	# This is a horrible hack. We run the BuckleScript build first, since the Menhir
	# configuration is already laid out in bsconfig.json; but remove the copied AST
	# implementation so Dune can copy-over the one with OCaml-specific annotations.
	./node_modules/.bin/bsb -make-world
	rm -f src/aST.ml
	dune build

src/uAX31.ml: pkg/ucd.nounihan.grouped.xml
	dune exec pkg/generate_uchar_ranges.exe $< > $@

pkg/ucd.nounihan.grouped.xml: pkg/ucd.nounihan.grouped.zip
	unzip -nd pkg/ $< ucd.nounihan.grouped.xml

pkg/ucd.nounihan.grouped.zip:
	curl http://www.unicode.org/Public/11.0.0/ucdxml/ucd.nounihan.grouped.zip -o $@

.PHONY: build-doc
build-doc:
	dune build --only-packages=excmd @doc
	# FIXME: There's gotta be a better way to clean up the docs ...
	-rm -r "_build/default/_doc/_html/excmd/Excmd/MenhirLib" \
		"_build/default/_doc/_html/excmd/Excmd__"* \
		"_build/default/_doc/_html/index.html"
	cp -Rv "_build/default/_doc/_html/" docs

.PHONY: clean-all
clean-all: clean
	rm -f src/uAX31.ml
	rm -f pkg/ucd.nounihan.grouped.*

.PHONY: clean
clean:
	rm -f src/aST.ml
	rm -f src/menhirLib.ml*
	rm -f src/parserAutomaton.ml src/parserAutomaton.mli
	rm -rf _build/
	rm -rf lib/
	./node_modules/.bin/bsb -clean-world
