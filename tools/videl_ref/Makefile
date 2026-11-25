# Golden model for the SV-Lite Videl core: Hatari's videl.c (S035) + stubs.
HATARI := ../../sources/web/github.com/hatari/hatari-36a8acf-videl
videl_ref: videl_ref.c $(wildcard stubs/*.h) $(HATARI)/videl.c
	$(CC) -O1 -w -Istubs -I$(HATARI) -o $@ videl_ref.c -lm
expected.txt: videl_ref vectors.txt
	./videl_ref vectors.txt > $@
clean:
	rm -f videl_ref
