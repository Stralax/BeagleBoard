#!/bin/bash

# Preveri, če je argument podan (1,2,3,4)
if [[ -z "$1" || ! "$1" =~ ^[1-4]$ ]]; then
    echo "Uporaba: $0 <1|2|3|4>"
    exit 1
fi

MODE="$1"

# Funkcija za klic "podpis" skripte glede na MODE in številko klica
call_podpis() {
    local call_index="$1"
    local input="$2"
    local script=""

    case "$MODE" in
        1)
            script="./static_podpis.sh"
            ;;
        2)
            script="./dynamic_podpis.sh"
            ;;
        3)
            if [ "$call_index" -eq 1 ]; then
                script="./fullDynamic_podpis.sh"
            else
                script="./fullDynamic_podpis.sh"
            fi
            ;;
		4)
            if [ "$call_index" -eq 1 ]; then
                script="./hybrid_registrtion.sh"
            else
                script="./hybrid_podpis.sh"
            fi
            ;;
    esac

    "$script" "$input"
}


# ------------------------
# 1. Pridobi prvi podpis ("Snoopy" pri prvem klicu)
# ------------------------
SIGNATURE=$(call_podpis 1 "Snoopy")
echo "Signature: $SIGNATURE"

# ------------------------
# 2. Pošlji POST zahtevo za registracijo
# ------------------------
START_TIME=$(date +%s%3N)  # začetni čas v milisekundah

REGISTER_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"signature\":\"$SIGNATURE\"}" \
    https://stralax-dfp-streznik.onrender.com/api/beagleBoard/register)

END_TIME=$(date +%s%3N)  # končni čas v milisekundah
ELAPSED=$((END_TIME - START_TIME))

#echo "Čas izvajanja: ${ELAPSED} ms"
#echo "Register response: $REGISTER_RESPONSE"

# ------------------------
# 3. Če je registracija uspešna, zaženi neskončno zanko
# ------------------------
if [[ "$REGISTER_RESPONSE" == *"true"* ]]; then
    # Pridobi ID naprave (drug klic podpis)
    DFP=$(call_podpis 2 "$REGISTER_RESPONSE")

    # Inicializiraj currentJOB
    currentJOB="None"

    echo 0 > DATA/working_state.txt
    echo None > DATA/current_job.txt

    while true; do
        # Pošlji trenutni job z metodo PUT
        
	START_TIME=$(date +%s%3N)
	
	RESPONSE=$(curl -s -X PUT \
            -H "Content-Type: application/json" \
            -d "{\"JOB\":\"$currentJOB\",\"DFP\":\"$DFP\"}" \
            "https://stralax-dfp-streznik.onrender.com/api/beagleBoard/job")

        echo "Odgovor strežnika: $RESPONSE"

        # Razdeli odgovor po presledku
        JOB_TYPE=$(echo "$RESPONSE" | awk '{print $1}')
        JOB_ARGS=$(echo "$RESPONSE" | cut -d' ' -f2-)

        # Če strežnik vrne nov job (ni enak trenutnemu)
        if [ "$RESPONSE" != "$currentJOB" ] && [ "$JOB_TYPE" != "None" ]; then
            currentJOB="$RESPONSE"

            echo "$JOB_TYPE" > DATA/current_job.txt
            echo 1 > DATA/working_state.txt

            (
                # Zaženi logic.sh kot ozadni proces in ujemi rezultat
                ./logic.sh "$JOB_TYPE" $JOB_ARGS > temp_output.txt
                RESULT=$(<temp_output.txt)
                rm temp_output.txt

                echo "logic.sh je koncal, izhod: $RESULT"

                # Po končanem job-u klic "podpis" skripte z REGISTER_RESPONSE
                DFP=$(call_podpis 2 "$REGISTER_RESPONSE")

                curl -s -X PUT \
                   -H "Content-Type: application/json" \
                   -d "{\"DFP\":\"$DFP\", \"RESULT\":\"$RESULT\"}" \
                   "https://stralax-dfp-streznik.onrender.com/api/beagleBoard/job-done"

                echo "Obvestilo o koncu job-a poslano, currentJOB resetiran na None."
                echo None > DATA/current_job.txt
                echo 0 > DATA/working_state.txt
            ) &
        fi


	END_TIME=$(date +%s%3N)  # kon�~Mni �~Mas v milisekundah
	ELAPSED=$((END_TIME - START_TIME))

		echo "�~Las izvajanja: ${ELAPSED} ms"
	echo "Register response: $REGISTER_RESPONSE"



        # Počakaj 3 sekunde preden pošlješ naslednji PUT
        sleep 3
    done
else
    echo "Registration failed (response ne vsebuje 'true')."
fi

