#!/bin/bash

# Rebuild the code
make main.exe

# Launch the python server
./python-server.py &
sleep 1

# Run fortran code
if ./main.exe; then
    echo "Passed!"
else
    echo "Tests failed!"
fi
