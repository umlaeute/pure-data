OBJ = pdgtk.o tclparser.o canvas.o net.o

pdgtk: $(OBJ); gcc -g -o pdgtk $$(pkg-config --cflags gtk4) \
    $(OBJ) $$(pkg-config --libs gtk4) -ltcl

tclparser.o: tclparser.c; gcc -g -c $<
net.o: net.c; gcc -g -c $<
pdgtk.o: pdgtk.c; gcc -g -c $$(pkg-config --cflags gtk4) $<
canvas.o: canvas.c; gcc -g -c $$(pkg-config --cflags gtk4) $<

$(OBJ): pdgtk.h

clean: ; rm -f pdgtk *.o
