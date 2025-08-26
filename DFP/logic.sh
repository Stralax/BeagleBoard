#!/bin/bash

# Preveri, če je vsaj en argument
if [ $# -lt 1 ]; then
    echo "Uporaba: $0 <job_type> [argumenti...]"
    exit 1
fi

# Prvi argument je tip joba (npr. "fibo")
JOB_TYPE="$1"
shift   # odstrani prvi argument
ARGS="$@"

script_path="./JOBS/${JOB_TYPE}.sh"

# Preveri, ali skripta obstaja
if [ ! -f "$script_path" ]; then
    echo "Skripta $script_path ne obstaja!"
    exit 1
fi

# Poženi ustrezno job skripto z dodatnimi argumenti
"$script_path" $ARGS

