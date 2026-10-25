all: main.exe


FLAGS := -fmax-errors=5 -Wall -Wextra

main.exe: main.f90 tcpsockets.f90 sockets.c
	gcc ${FLAGS} -c sockets.c
	gfortran ${FLAGS} -c tcpsockets.f90
	gfortran -c main.f90
	gfortran -o main.exe main.o tcpsockets.o sockets.o


clean:
	rm -f *.o *.mod *~ \#*\# main.exe
