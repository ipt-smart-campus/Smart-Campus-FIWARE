"""
Poller: Open-Meteo → Orion-LD (NGSI-LD)
Publica entidade WeatherObserved com dados meteorológicos do campus.
"""

import os
import time
import logging
import requests
from datetime import datetime, timezone

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

ORION_URL     = os.environ.get("ORION_URL", "http://orion:1026")
CONTEXT_URL   = os.environ.get("CONTEXT_URL", "http://context-server/campus-context.jsonld")
CAMPUS_LAT    = float(os.environ.get("CAMPUS_LAT", "39.6024"))
CAMPUS_LON    = float(os.environ.get("CAMPUS_LON", "-8.4130"))
POLL_INTERVAL = int(os.environ.get("POLL_INTERVAL", "300"))
TENANT        = os.environ.get("FIWARE_TENANT", "smartcampus")

ENTITY_ID = "urn:ngsi-ld:WeatherObserved:IPT-Campus-001"

OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"
OPEN_METEO_PARAMS = {
    "latitude": CAMPUS_LAT,
    "longitude": CAMPUS_LON,
    "current": "temperature_2m,relative_humidity_2m,surface_pressure,wind_speed_10m,precipitation",
    "wind_speed_unit": "ms",
    "timezone": "Europe/Lisbon",
}

# Headers base — o @context vai no header Link, não no body
HEADERS_JSON_LD = {
    "Content-Type": "application/ld+json",
    "Accept": "application/ld+json",
    "NGSILD-Tenant": TENANT,
}

# Para PATCH de atributos o Content-Type é application/ld+json
# e o @context vai no body (é obrigatório no PATCH)
HEADERS_PATCH = {
    "Content-Type": "application/ld+json",
    "NGSILD-Tenant": TENANT,
}


def fetch_weather():
    resp = requests.get(OPEN_METEO_URL, params=OPEN_METEO_PARAMS, timeout=10)
    resp.raise_for_status()
    return resp.json()["current"]


def build_entity(weather: dict) -> dict:
    observed_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return {
        "@context": CONTEXT_URL,
        "id": ENTITY_ID,
        "type": "WeatherObserved",
        "location": {
            "type": "GeoProperty",
            "value": {
                "type": "Point",
                "coordinates": [CAMPUS_LON, CAMPUS_LAT],
            },
        },
        "temperature": {
            "type": "Property",
            "value": weather["temperature_2m"],
            "unitCode": "CEL",
            "observedAt": observed_at,
        },
        "humidity": {
            "type": "Property",
            "value": weather["relative_humidity_2m"],
            "unitCode": "P1",
            "observedAt": observed_at,
        },
        "pressure": {
            "type": "Property",
            "value": weather["surface_pressure"],
            "unitCode": "A97",
            "observedAt": observed_at,
        },
        "windSpeed": {
            "type": "Property",
            "value": weather["wind_speed_10m"],
            "unitCode": "MTS",
            "observedAt": observed_at,
        },
        "precipitation": {
            "type": "Property",
            "value": weather["precipitation"],
            "unitCode": "MMT",
            "observedAt": observed_at,
        },
    }


def build_attrs(entity: dict) -> dict:
    """Extrai só os atributos para o PATCH (sem id e type, com @context)."""
    attrs = {k: v for k, v in entity.items() if k not in ("id", "type")}
    return attrs  # @context já vem do build_entity


def upsert_entity(entity: dict):
    url_patch = f"{ORION_URL}/ngsi-ld/v1/entities/{ENTITY_ID}/attrs"
    attrs = build_attrs(entity)

    resp = requests.patch(url_patch, json=attrs, headers=HEADERS_PATCH, timeout=10)
    log.debug("PATCH %s → %s %s", url_patch, resp.status_code, resp.text[:300])

    if resp.status_code == 404:
        # Entidade não existe ainda — cria
        resp = requests.post(
            f"{ORION_URL}/ngsi-ld/v1/entities",
            json=entity,
            headers=HEADERS_JSON_LD,
            timeout=10,
        )
        if resp.status_code in (200, 201):
            log.info("Entidade criada: %s (tenant: %s)", ENTITY_ID, TENANT)
        else:
            log.error("Erro ao criar entidade: %s %s", resp.status_code, resp.text)
            resp.raise_for_status()
    elif resp.status_code in (200, 204, 207):
        log.info("Entidade atualizada: %s (tenant: %s)", ENTITY_ID, TENANT)
    else:
        log.error("Erro ao atualizar entidade: %s %s", resp.status_code, resp.text)


def main():
    log.info(
        "Poller iniciado. Intervalo: %ds | Campus: %.4f, %.4f | Tenant: %s",
        POLL_INTERVAL, CAMPUS_LAT, CAMPUS_LON, TENANT,
    )
    while True:
        try:
            weather = fetch_weather()
            entity  = build_entity(weather)
            upsert_entity(entity)
        except requests.RequestException as e:
            log.error("Erro de rede: %s", e)
        except Exception as e:
            log.exception("Erro inesperado: %s", e)
        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()
