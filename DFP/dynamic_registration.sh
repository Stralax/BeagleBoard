START_TIME=$(date +%s%3N)  # za�~Metni �~Mas v milisekundah

for i in {1..19}; do
    a=$(./fullDynamic_podpis.sh "ALO")
done

alo=$(./dynamic_podpis.sh "ALO")
echo $alo

END_TIME=$(date +%s%3N)  # kon�~Mni �~Mas v milisekundah
ELAPSED=$((END_TIME - START_TIME))

echo "�~Las izvajanja: ${ELAPSED} ms"
echo "Register response: $REGISTER_RESPONSE"

