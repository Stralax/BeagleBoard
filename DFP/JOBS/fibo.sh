#!/bin/bash

if [ -z "$1" ]; then
    n=555
else
    n=$1
fi

# Preveri, da je n celo število
if ! [[ "$n" =~ ^[0-9]+$ ]]; then
    echo "Error: n must be integer >= 0"
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
    tmp=$(echo "$a + $b" | bc)  # novo število
    a=$b                        # premaknemo naprej
    b=$tmp
done

echo "$b" | tr -d '[:space:]' | tr -d '\\'

