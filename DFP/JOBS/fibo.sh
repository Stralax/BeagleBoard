#!/bin/bash

n=1
if [ -z "$1" ]; then
    n=555
else 
    n=$1
fi

if [ "$n" -lt 0 ]; then
    echo "Error: n must be >= 0"
    exit 1
fi

if [ "$n" -eq 0 ]; then
    echo 0
    exit 0
elif [ "$n" -eq 1 ]; then
    echo 1
    exit 0
fi

a=0
b=1

for ((i=2; i<=n; i++)); do
    b=$(echo "$a + $b" | bc)
    a=$(echo "$b - $a" | bc)
done

echo "$b" | tr -d '[:space:]' | tr -d '\\'

