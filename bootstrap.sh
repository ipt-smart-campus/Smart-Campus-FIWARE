#!/usr/bin/env bash
# bootstrap.sh
# Regista o serviço e os dispositivos simulados no IoT Agent.
# Corre UMA VEZ após o stack estar de pé.
#
# Uso: ./bootstrap.sh

set -euo pipefail

IOTA_URL="http://localhost:4041"
ORION_URL="http://localhost:1026"
CRATE_URL="http://localhost:4200"
API_KEY="campus2025"
FIWARE_SERVICE="smartcampus"
FIWARE_SERVICEPATH="/"

echo "=== A verificar estado actual ==="
EXISTING=$(curl -s "$IOTA_URL/iot/devices" \
  -H "fiware-service: $FIWARE_SERVICE" \
  -H "fiware-servicepath: $FIWARE_SERVICEPATH" | jq '.count // 0')

if [ "$EXISTING" -gt "0" ]; then
  echo "Stack já inicializado ($EXISTING dispositivos registados)."
  echo "Para forçar re-inicialização, remove os dispositivos manualmente."
  exit 0
fi

echo "=== A registar serviço no IoT Agent ==="
curl -sf -X POST "$IOTA_URL/iot/services" \
  -H "Content-Type: application/json" \
  -H "fiware-service: $FIWARE_SERVICE" \
  -H "fiware-servicepath: $FIWARE_SERVICEPATH" \
  -d @- <<EOF
{
  "services": [
    {
      "apikey":      "$API_KEY",
      "cbroker":     "http://orion:1026",
      "entity_type": "IndoorEnvironmentObserved",
      "resource":    "/iot/json"
    }
  ]
}
EOF
echo -e "\n Serviço registado"

echo ""
echo "=== A registar sensor sala 101 ==="
curl -sf -X POST "$IOTA_URL/iot/devices" \
  -H "Content-Type: application/json" \
  -H "fiware-service: $FIWARE_SERVICE" \
  -H "fiware-servicepath: $FIWARE_SERVICEPATH" \
  -d @- <<EOF
{
  "devices": [
    {
      "device_id":   "sensor-temp-sala101",
      "entity_name": "urn:ngsi-ld:IndoorEnvironmentObserved:Sala101",
      "entity_type": "IndoorEnvironmentObserved",
      "attributes": [
        { "object_id": "temperature", "name": "temperature", "type": "Number" },
        { "object_id": "humidity",    "name": "humidity",    "type": "Number" },
        { "object_id": "co2",         "name": "co2",         "type": "Number" }
      ],
      "static_attributes": [
        { "name": "refRoom",     "type": "Relationship", "value": "urn:ngsi-ld:Room:Sala101" },
        { "name": "refBuilding", "type": "Relationship", "value": "urn:ngsi-ld:Building:EdificioI" }
      ]
    }
  ]
}
EOF
echo -e "\n Sensor sala 101 registado"

echo ""
echo "=== A registar sensor sala 201 ==="
curl -sf -X POST "$IOTA_URL/iot/devices" \
  -H "Content-Type: application/json" \
  -H "fiware-service: $FIWARE_SERVICE" \
  -H "fiware-servicepath: $FIWARE_SERVICEPATH" \
  -d @- <<EOF
{
  "devices": [
    {
      "device_id":   "sensor-temp-sala201",
      "entity_name": "urn:ngsi-ld:IndoorEnvironmentObserved:Sala201",
      "entity_type": "IndoorEnvironmentObserved",
      "attributes": [
        { "object_id": "temperature", "name": "temperature", "type": "Number" },
        { "object_id": "humidity",    "name": "humidity",    "type": "Number" },
        { "object_id": "co2",         "name": "co2",         "type": "Number" }
      ],
      "static_attributes": [
        { "name": "refRoom",     "type": "Relationship", "value": "urn:ngsi-ld:Room:Sala201" },
        { "name": "refBuilding", "type": "Relationship", "value": "urn:ngsi-ld:Building:EdificioI" }
      ]
    }
  ]
}
EOF
echo -e "\n Sensor sala 201 registado"

echo ""
echo "=== A registar sensor de energia ==="
# NOTA: usa IndoorEnvironmentObserved (mesmo tipo do serviço) para o IoT Agent
# mapear correctamente via apikey campus2025. O atributo powerConsumption
# diferencia-o das salas. EnergyConsumptionSensor como entity_type causaria
# falha de mapeamento com o QuantumLeap 0.7.5 + NGSI-LD.
curl -sf -X POST "$IOTA_URL/iot/devices" \
  -H "Content-Type: application/json" \
  -H "fiware-service: $FIWARE_SERVICE" \
  -H "fiware-servicepath: $FIWARE_SERVICEPATH" \
  -d @- <<EOF
{
  "devices": [
    {
      "device_id":   "sensor-energy-edificio",
      "entity_name": "urn:ngsi-ld:IndoorEnvironmentObserved:sensor-energy-edificio",
      "entity_type": "IndoorEnvironmentObserved",
      "attributes": [
        { "object_id": "powerConsumption", "name": "powerConsumption", "type": "Number" }
      ],
      "static_attributes": [
        { "name": "refBuilding", "type": "Relationship", "value": "urn:ngsi-ld:Building:EdificioI" }
      ]
    }
  ]
}
EOF
echo -e "\n Sensor de energia registado"

echo ""
echo "=== A criar tabelas no CrateDB ==="
# O QuantumLeap 0.7.5 não cria tabelas automaticamente com payloads NGSI-LD.
# Criação manual necessária antes da primeira notificação.
curl -sf -X POST "$CRATE_URL/_sql" \
  -H "Content-Type: application/json" \
  -d '{
    "stmt": "CREATE TABLE IF NOT EXISTS doc.etindoorenvironmentobserved (entity_id STRING, entity_type STRING, fiware_servicepath STRING, temperature STRING, humidity STRING, co2 STRING, time_index TIMESTAMP) WITH (number_of_replicas = 0)"
  }' >/dev/null
echo "Tabela IndoorEnvironmentObserved criada"

# Adiciona coluna powerConsumption para o sensor de energia
# (ALTER TABLE é idempotente com IF NOT EXISTS no CrateDB 3.x via excepção ignorada)
curl -s -X POST "$CRATE_URL/_sql" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "ALTER TABLE doc.etindoorenvironmentobserved ADD COLUMN powerconsumption STRING"}' >/dev/null 2>&1 || true
echo "Coluna powerConsumption adicionada"

curl -sf -X POST "$CRATE_URL/_sql" \
  -H "Content-Type: application/json" \
  -d '{
    "stmt": "CREATE TABLE IF NOT EXISTS doc.etweatherobserved (entity_id STRING, entity_type STRING, fiware_servicepath STRING, temperature STRING, humidity STRING, pressure STRING, windspeed STRING, precipitation STRING, time_index TIMESTAMP) WITH (number_of_replicas = 0)"
  }' >/dev/null
echo "Tabela WeatherObserved criada"

echo ""
echo "=== A criar subscrição Orion → QuantumLeap ==="
curl -sf -X POST "$ORION_URL/ngsi-ld/v1/subscriptions" \
  -H "Content-Type: application/ld+json" \
  -H "NGSILD-Tenant: $FIWARE_SERVICE" \
  -d @- <<EOF
{
  "@context": "http://context-server/campus-context.jsonld",
  "description": "Notifica QuantumLeap de todas as mudanças de entidades",
  "type": "Subscription",
  "entities": [
    { "type": "WeatherObserved" },
    { "type": "IndoorEnvironmentObserved" }
  ],
  "notification": {
    "endpoint": {
      "uri": "http://quantumleap:8668/v2/notify",
      "accept": "application/json"
    }
  }
}
EOF
echo -e "\n Subscrição QuantumLeap criada"

echo ""
echo "=== Bootstrap concluído ==="
echo ""
echo "NOTA: O histórico de powerConsumption não é persistido pelo QuantumLeap 0.7.5"
echo "com payloads NGSI-LD (tipo 'Property' não suportado). O estado actual da"
echo "entidade está disponível no Orion."
