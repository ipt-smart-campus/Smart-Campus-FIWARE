#!/usr/bin/env bash
# bootstrap.sh
# Regista o serviço e os dispositivos simulados no IoT Agent.
# Corre UMA VEZ após o stack estar de pé.
#
# Uso: ./bootstrap.sh

set -euo pipefail

IOTA_URL="http://localhost:4041"
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
curl -sf -X POST "$IOTA_URL/iot/devices" \
  -H "Content-Type: application/json" \
  -H "fiware-service: $FIWARE_SERVICE" \
  -H "fiware-servicepath: $FIWARE_SERVICEPATH" \
  -d @- <<EOF
{
  "devices": [
    {
      "device_id":   "sensor-energy-edificio",
      "entity_name": "urn:ngsi-ld:EnergyConsumptionSensor:EdificioI",
      "entity_type": "EnergyConsumptionSensor",
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
echo "=== A criar subscrição Orion → QuantumLeap ==="
curl -sf -X POST "http://localhost:1026/ngsi-ld/v1/subscriptions" \
  -H "Content-Type: application/ld+json" \
  -H "NGSILD-Tenant: $FIWARE_SERVICE" \
  -d @- <<EOF
{
  "@context": "http://context-server/campus-context.jsonld",
  "description": "Notifica QuantumLeap de todas as mudanças de entidades",
  "type": "Subscription",
  "entities": [
    { "type": "WeatherObserved" },
    { "type": "IndoorEnvironmentObserved" },
    { "type": "EnergyConsumptionSensor" }
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
