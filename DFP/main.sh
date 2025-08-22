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

    while true; do
        # Pošlji trenutni job z metodo PUT
        RESPONSE=$(curl -s -X PUT \
            -H "Content-Type: application/json" \
            -d "{\"JOB\":\"$currentJOB\",\"DFP\":\"$DFP\"}" \
            "https://stralax-dfp-streznik.onrender.com/api/beagleBoard/job")

        echo "Odgovor strežnika: $RESPONSE"

        # Če strežnik vrne nov job (ni enak trenutnemu)
        if [ "$RESPONSE" != "$currentJOB" ]; then
            
	     currentJOB="fibo"

	     (
                # Zaženi logic.sh kot ozadni proces in ujemi rezultat
                ./logic.sh "$RESPONSE" > temp_output.txt
                RESULT=$(<temp_output.txt)     # preberi izhod iz datoteke
                rm temp_output.txt             # počisti začasno datoteko

                echo "logic.sh je koncal, izhod: $RESULT"

		DFP=$(./podpis.sh)

                curl -s -X PUT \
        	   -H "Content-Type: application/json" \
        	   -d "{\"DFP\":\"$DFP\", \"RESULT\":\"$RESULT\"}" \
        	   "https://stralax-dfp-streznik.onrender.com/api/beagleBoard/job-done"

                echo "Obvestilo o koncu job-a poslano, currentJOB resetiran na None."
            ) &
        fi

        # Počakaj 3 sekunde preden pošlješ naslednji PUT
        sleep 3
    done
else
    echo "Registration failed (response ne vsebuje 'true')."
fi

