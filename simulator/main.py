"""
Simulador de sensores MQTT para o Smart Campus IPT.
Publica dados simulados no tópico esperado pelo IoT Agent for JSON.

Formato de tópico: /iot/json/<apikey>/<device_id>/attrs
"""

import os
import time
import json
import random
import logging
import paho.mqtt.client as mqtt

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

MQTT_HOST         = os.environ.get("MQTT_HOST", "mosquitto")
MQTT_PORT         = int(os.environ.get("MQTT_PORT", "1883"))
SIMULATE_INTERVAL = int(os.environ.get("SIMULATE_INTERVAL", "60"))

# API key definida no registo do serviço no IoT Agent
API_KEY = "campus2025"

# Dispositivos simulados: (device_id, tipo)
DEVICES = [
    ("sensor-temp-sala101",   "room"),
    ("sensor-temp-sala201",   "room"),
    ("sensor-energy-edificio","energy"),
]


def simulate_room_sensor(device_id: str) -> dict:
    """Simula sensor de temperatura e humidade de sala."""
    return {
        "temperature": round(random.uniform(18.0, 26.0), 1),
        "humidity":    round(random.uniform(40.0, 70.0), 1),
        "co2":         round(random.uniform(400.0, 1200.0), 0),
    }


def simulate_energy_sensor(device_id: str) -> dict:
    """Simula leitor de energia."""
    return {
        "powerConsumption": round(random.uniform(5.0, 50.0), 2),
    }


def publish_device(client: mqtt.Client, device_id: str, sensor_type: str):
    topic = f"/{API_KEY}/{device_id}/attrs" 

    if sensor_type == "room":
        payload = simulate_room_sensor(device_id)
    elif sensor_type == "energy":
        payload = simulate_energy_sensor(device_id)
    else:
        return

    client.publish(topic, json.dumps(payload), qos=1)
    log.info("Publicado %s → %s", topic, payload)


def main():
    client = mqtt.Client(client_id="campus-simulator", protocol=mqtt.MQTTv311)

    def on_connect(c, userdata, flags, rc):
        if rc == 0:
            log.info("Ligado ao Mosquitto")
        else:
            log.error("Falha na ligação MQTT: rc=%d", rc)

    client.on_connect = on_connect

    # Tenta ligar com retry
    while True:
        try:
            client.connect(MQTT_HOST, MQTT_PORT, keepalive=60)
            break
        except Exception as e:
            log.warning("Mosquitto não disponível ainda: %s — a tentar em 5s", e)
            time.sleep(5)

    client.loop_start()

    log.info("Simulador iniciado. Intervalo: %ds", SIMULATE_INTERVAL)
    while True:
        for device_id, sensor_type in DEVICES:
            try:
                publish_device(client, device_id, sensor_type)
            except Exception as e:
                log.error("Erro ao publicar %s: %s", device_id, e)
        time.sleep(SIMULATE_INTERVAL)


if __name__ == "__main__":
    main()
