#!/bin/bash

# Preveri, ce je vsaj en argument
if [ $# -lt 1 ]; then
    echo "Uporaba: $0 <ime_skripte> [argumenti...]"
    exit 1
fi

# Prvi argument je ime skripte
script_name=$1
script_path="./JOBS/${script_name}.sh"

# Preveri, ali skripta obstaja
if [ ! -f "$script_path" ]; then
    echo "Skripta $script_path ne obstaja!"
    exit 1
fi

# Pošlji vse ostale argumente skripti
shift 1
"$script_path" "$@"

