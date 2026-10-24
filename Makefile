all: main.exe


main.exe: main.f90 f90sockets.f90 csockets.c
	gcc -c csockets.c
	gfortran -c f90sockets.f90
	gfortran -c main.f90
	gfortran -o main.exe main.o f90sockets.o csockets.o


clean:
	rm -f *.o *.mod *~ \#*\# main.exe
