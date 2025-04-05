SRC_DIR ?= src
DOC_DIR ?= doc
TESTS_DIR ?= tests

all: fmt vet missdoc test

fmt:
	v fmt -verify -diff $(SRC_DIR)

vet:
	v vet -W -r -I -F $(SRC_DIR)

missdoc:
	v missdoc -r --verify $(SRC_DIR)

test:
	v test .

doc:
	v doc -f html -m . -o $(DOC_DIR)

clean:
	rm -r $(DOC_DIR) || true

serve: clean doc
	v -e "import net.http.file; file.serve(folder: '$(DOC_DIR)')"
