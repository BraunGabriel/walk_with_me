#!/bin/bash
# Simulate walking a tour on the booted iOS simulator.
# Usage: ./scripts/sim_walk.sh [tour-id] [speed m/s]
#   ./scripts/sim_walk.sh highlights        # walking pace (1.4 m/s)
#   ./scripts/sim_walk.sh highlights 10     # fast-forward
# Stop early with: xcrun simctl location booted clear
set -e
cd "$(dirname "$0")/.."

TOUR="${1:-highlights}"
SPEED="${2:-1.4}"

WAYPOINTS=$(python3 -I - "$TOUR" <<'EOF'
import json, sys
tour_id = sys.argv[1]
pois = {p["id"]: p for p in json.load(open("assets/data/pois.json"))["pois"]}
tours = {t["id"]: t for t in json.load(open("assets/data/tours.json"))["tours"]}
if tour_id not in tours:
    sys.exit(f"Unknown tour '{tour_id}'. Options: {', '.join(tours)}")
for stop in tours[tour_id]["stops"]:
    print(f'{pois[stop]["latitude"]},{pois[stop]["longitude"]}')
EOF
)

echo "Walking tour '$TOUR' at ${SPEED} m/s:"
echo "$WAYPOINTS"
echo "$WAYPOINTS" | xcrun simctl location booted start --speed="$SPEED" -
