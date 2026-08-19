# Smart Campus Core — FIWARE NGSI-LD

## Serviços

| Serviço         | Porto | Função                                      |
|-----------------|-------|---------------------------------------------|
| orion           | 1026  | Context Broker NGSI-LD                      |
| mongodb         | —     | Base de dados do Orion e IoT Agent          |
| cratedb         | 4200  | Time series backend (UI em :4200)           |
| quantumleap     | 8668  | Persiste histórico via subscrição do Orion  |
| mosquitto       | 1883  | MQTT broker                                 |
| iot-agent       | 4041  | Traduz MQTT JSON → NGSI-LD                  |
| context-server  | 3004  | Serve o @context JSON-LD                    |
| poller          | —     | Open-Meteo → Orion (a cada 5 min)           |
| simulator       | —     | Publica dados simulados via MQTT            |
| prometheus      | 9090  | Métricas                                    |
| grafana         | 3000  | Dashboards (admin/admin)                    |

## Estrutura de ficheiros

```
.
├── docker-compose.yml
├── bootstrap.sh              # correr uma vez após o stack estar de pé
├── context/
│   └── campus-context.jsonld # @context NGSI-LD do campus
├── mosquitto/
│   └── mosquitto.conf
├── poller/
│   ├── Dockerfile
│   ├── main.py
│   └── requirements.txt
├── prometheus/
│   └── prometheus.yml
├── simulator/
│   ├── Dockerfile
│   ├── main.py
│   └── requirements.txt
└── grafana/
    └── provisioning/         # datasources e dashboards (criar manualmente)
```

## Como arrancar

```bash
# 1. Subir o stack
docker compose up -d

# 2. Aguardar todos os serviços ficarem healthy (~60s)
docker compose ps

# 3. Registar serviços, dispositivos e subscrição (UMA VEZ)
chmod +x bootstrap.sh
./bootstrap.sh
```

## Verificar que funciona

```bash
# Entidades no Orion (com contexto para nomes curtos)
curl -s "http://localhost:1026/ngsi-ld/v1/entities?type=WeatherObserved" \
  -H "Accept: application/json" \
  -H "NGSILD-Tenant: smartcampus" \
  -H 'Link: <http://context-server/campus-context.jsonld>; rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' | jq .

# Histórico no QuantumLeap
curl -s "http://localhost:8668/v2/entities/urn:ngsi-ld:WeatherObserved:IPT-Campus-001/attrs/temperature"

# Dispositivos registados no IoT Agent
curl -s http://localhost:4041/iot/devices \
  -H "fiware-service: smartcampus" \
  -H "fiware-servicepath: /" | jq .
```

## Substituir simulador por sensor real

Quando obter acesso ao leitor de energia/temperatura real:
1. Para o simulador: `docker compose stop simulator`
2. Configura o hardware para publicar no tópico `/iot/json/campus2025/<device_id>/attrs`
3. O IoT Agent processa automaticamente — não precisas de mudar mais nada.

## Notas importantes

- O `bootstrap.sh` só precisa de correr **uma vez** porque o IoT Agent usa `IOTA_REGISTRY_TYPE=mongodb`.
- O `@context` em `context/campus-context.jsonld` é servido pelo `context-server` na porta 3004.
  Qualquer alteração ao contexto requer reiniciar o `context-server`.
- A subscrição Orion → QuantumLeap cobre todas as entidades dos 3 tipos definidos.
  Se adicionares novos tipos de entidade, adiciona-os à subscrição.
