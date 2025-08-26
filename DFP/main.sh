#!/bin/bash

# 1. Pridobi podpis naprave
SIGNATURE=$(./podpis.sh)
echo "Signature: $SIGNATURE"

# 2. Pošlji POST zahtevo za registracijo
REGISTER_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"signature\":\"$SIGNATURE\"}" \
    https://stralax-dfp-streznik.onrender.com/api/beagleBoard/register)

echo "Register response: $REGISTER_RESPONSE"

# 3. Če je registracija uspešna, zaženi neskončno zanko
if [[ "$REGISTER_RESPONSE" == *"true"* ]]; then
    # Pridobi ID naprave (lahko je isti kot SIGNATURE, odvisno od tvoje logike)
    DFP=$(./podpis.sh)

    # Inicializiraj currentJOB
    currentJOB="None"

    echo 0 > DATA/working_state.txt
    echo None > DATA/current_job.txt

    while true; do
        # Pošlji trenutni job z metodo PUT
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

                DFP=$(./podpis.sh)

                curl -s -X PUT \
                   -H "Content-Type: application/json" \
                   -d "{\"DFP\":\"$DFP\", \"RESULT\":\"$RESULT\"}" \
                   "https://stralax-dfp-streznik.onrender.com/api/beagleBoard/job-done"

                echo "Obvestilo o koncu job-a poslano, currentJOB resetiran na None."
                echo None > DATA/current_job.txt
                echo 0 > DATA/working_state.txt
            ) &
        fi

        # Počakaj 3 sekunde preden pošlješ naslednji PUT
        sleep 3
    done
else
    echo "Registration failed (response ne vsebuje 'true')."
fi
 
