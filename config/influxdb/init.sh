#!/usr/bin/env bash
set -euo pipefail

INFLUX_URL="${INFLUXDB_URL:-http://localhost:8086}"
ORG_NAME="${INFLUX_INIT_ORG:?INFLUX_INIT_ORG is required}"
BUCKET_NAME="${INFLUX_INIT_BUCKET:?INFLUX_INIT_BUCKET is required}"
RETENTION="${INFLUX_INIT_RETENTION:-30d}"
ADMIN_TOKEN="${INFLUX_INIT_ADMIN_TOKEN:?INFLUX_INIT_ADMIN_TOKEN is required}"

echo "🔧 Idempotent InfluxDB initialization for PlanetPlant..."

# Wait until Influx HTTP API responds
echo "Waiting for InfluxDB at ${INFLUX_URL} ..."
for i in {1..60}; do
  if curl -sf "${INFLUX_URL}/health" >/dev/null; then
    echo "✅ InfluxDB is up."
    break
  fi
  sleep 2
  if [ "$i" -eq 60 ]; then
    echo "❌ InfluxDB did not become healthy in time." >&2
    exit 1
  fi
done

# Helper function: JSON from curl
curl_json() {
  curl -sS -H "Authorization: Token ${ADMIN_TOKEN}" -H "Content-Type: application/json" "$@"
}

# Get/create org (idempotent)
ORG_ID="$(curl_json "${INFLUX_URL}/api/v2/orgs?org=${ORG_NAME}" | jq -r '.orgs[0].id // empty')"
if [ -z "${ORG_ID}" ] || [ "${ORG_ID}" = "null" ]; then
  echo "Creating org ${ORG_NAME} ..."
  ORG_ID="$(curl_json -X POST "${INFLUX_URL}/api/v2/orgs" \
    --data "$(jq -nc --arg n "${ORG_NAME}" '{name:$n}')" | jq -r '.id')"
  echo "Created org id: ${ORG_ID}"
else
  echo "Org ${ORG_NAME} exists (id: ${ORG_ID})."
fi

# Get/create bucket (idempotent)
BUCKET_ID="$(curl_json "${INFLUX_URL}/api/v2/buckets?name=${BUCKET_NAME}&orgID=${ORG_ID}" | jq -r '.buckets[0].id // empty')"
if [ -z "${BUCKET_ID}" ] || [ "${BUCKET_ID}" = "null" ]; then
  echo "Creating bucket ${BUCKET_NAME} with retention ${RETENTION} ..."
  
  # Convert retention to seconds (30d -> 30*24*3600)
  to_seconds() {
    local v="$1"
    if [[ "$v" =~ ^([0-9]+)d$ ]]; then echo $((${BASH_REMATCH[1]}*24*3600))
    elif [[ "$v" =~ ^([0-9]+)h$ ]]; then echo $((${BASH_REMATCH[1]}*3600))
    elif [[ "$v" =~ ^0$ ]]; then echo 0
    else echo 0; fi
  }
  RP_SECONDS="$(to_seconds "${RETENTION}")"
  
  BUCKET_ID="$(curl_json -X POST "${INFLUX_URL}/api/v2/buckets" \
    --data "$(jq -nc --arg n "${BUCKET_NAME}" --arg oid "${ORG_ID}" --argjson rp "${RP_SECONDS}" \
    '{name:$n, orgID:$oid, retentionRules:[{type:"expire", everySeconds:$rp}]}')" | jq -r '.id')"
  echo "Created bucket id: ${BUCKET_ID}"
else
  echo "Bucket ${BUCKET_NAME} exists (id: ${BUCKET_ID})."
fi

echo "🌱 InfluxDB initialization completed (idempotent)."