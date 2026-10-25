all: main.exe


FLAGS := -fmax-errors=5 -Wall -Wextra

main.exe: main.f90 tcpsockets.o sockets.o
	gfortran -c main.f90
	gfortran -o main.exe main.o tcpsockets.o sockets.o


tcpsockets.o: tcpsockets.f90
	gfortran ${FLAGS} -c tcpsockets.f90

tcpsockets.f90: tcpsockets.fypp
	fypp tcpsockets.fypp tcpsockets.f90

sockets.o: sockets.c
	gcc ${FLAGS} -c sockets.c	

clean:
	rm -f *.o *.mod *~ \#*\# main.exe tcpsockets.f90
