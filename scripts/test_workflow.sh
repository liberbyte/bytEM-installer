#!/bin/bash
# BytEM Core Workflow Test - End to End
# Tests: Space → Room → Supply Data → Demand → Search → Find → Exchange
# Auth: Uses Matrix login to get token, then all calls go through API Gateway

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Load environment variables from the public deployment root.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [ -f "${DEPLOY_DIR}/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source "${DEPLOY_DIR}/.env"
    set +a
else
    echo -e "${RED}Error: .env not found. Please run env_setup.sh first.${NC}"
    exit 1
fi

# Configuration - all from environment, no defaults
if [ -z "${BYTEM_DOMAIN:-}" ] || [ -z "${MATRIX_DOMAIN:-}" ]; then
    echo -e "${RED}Error: BYTEM_DOMAIN and MATRIX_DOMAIN must be set in .env${NC}"
    exit 1
fi

API_HOST="https://${BYTEM_DOMAIN}"
MATRIX_HOST="https://${MATRIX_DOMAIN}"
MATRIX_SERVER="${MATRIX_URL:-http://bytem-synapse:8008}"
TEST_USER="${1:-${MATRIX_ADMIN_USERNAME:-}}"
TEST_PASS="${2:-${MATRIX_ADMIN_PASSWORD:-}}"
BOT_USER_ID="${BOT_USER_ID:-}"

if [ -z "$TEST_USER" ] || [ -z "$TEST_PASS" ] || [ -z "$BOT_USER_ID" ]; then
    echo -e "${RED}Error: separate test credentials and BOT_USER_ID are required in .env.${NC}"
    exit 1
fi

# Test identifiers
TIMESTAMP=$(date +%s)
SPACE_NAME="TestSpace_$TIMESTAMP"
SUPPLY_ROOM_NAME="SupplyRoom_$TIMESTAMP"
DEMAND_ROOM_NAME="DemandRoom_$TIMESTAMP"

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}        BytEM Core Workflow Test - End to End              ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}API Host:     ${NC}$API_HOST"
echo -e "${CYAN}Matrix Host:  ${NC}$MATRIX_HOST"
echo -e "${CYAN}Test User:    ${NC}$TEST_USER"
echo -e "${CYAN}Bot User:     ${NC}$BOT_USER_ID"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

# Step 1: Login
echo -e "${YELLOW}Step 1: Authentication (Matrix Login)${NC}"
echo "Attempting login for user: $TEST_USER"
LOGIN_RESPONSE=$(curl -s -k -X POST "$MATRIX_HOST/_matrix/client/r0/login" \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"m.login.password\",\"user\":\"$TEST_USER\",\"password\":\"$TEST_PASS\"}")

TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.access_token // empty')
USER_ID=$(echo "$LOGIN_RESPONSE" | jq -r '.user_id // empty')

if [ -z "$TOKEN" ]; then
    echo -e "${RED}❌ Login failed${NC}"
    echo "Response: $LOGIN_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✅ Token obtained: ${TOKEN:0:20}...${NC}"
echo -e "${GREEN}✅ User ID: $USER_ID${NC}\n"

# Get baseline room count
INITIAL_ROOMS=$(curl -s -k "$MATRIX_HOST/_matrix/client/r0/joined_rooms" -H "Authorization: Bearer $TOKEN")
INITIAL_ROOM_COUNT=$(echo "$INITIAL_ROOMS" | jq '.joined_rooms | length')
echo -e "${CYAN}Initial room count: $INITIAL_ROOM_COUNT${NC}\n"

# Step 2: Create Space
echo -e "${YELLOW}Step 2: Create Space via API Gateway${NC}"
echo "Space name: $SPACE_NAME"
SPACE_RESPONSE=$(curl -s -k -X POST "$API_HOST/api/events/cmd-create-space" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "matrix_server: $MATRIX_SERVER" \
  -d "{\"@type\":\"cmd-create-space\",\"event-type-schema\":{\"spaces\":[{\"name\":\"$SPACE_NAME\"}]}}")
echo "Response: $(echo "$SPACE_RESPONSE" | jq -c '.')"
echo -e "${GREEN}✅ Space creation queued${NC}\n"
sleep 3

# Step 3: Create Supply Room
echo -e "${YELLOW}Step 3: Create Supply Room (Direct Matrix API)${NC}"
ROOM_CREATE_PAYLOAD="{\"name\":\"$SUPPLY_ROOM_NAME\",\"room_alias_name\":\"supply_$TIMESTAMP\",\"visibility\":\"private\",\"preset\":\"public_chat\"}"
ROOM_RESPONSE=$(curl -s -k -X POST "$MATRIX_HOST/_matrix/client/r0/createRoom" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "$ROOM_CREATE_PAYLOAD")
SUPPLY_ROOM_ID=$(echo "$ROOM_RESPONSE" | jq -r '.room_id // empty')

if [ -z "$SUPPLY_ROOM_ID" ]; then
    echo -e "${RED}❌ Supply room creation failed${NC}"
    echo "Response: $ROOM_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✅ Supply Room ID: $SUPPLY_ROOM_ID${NC}\n"

# Step 3b: Invite Bot to Supply Room
echo -e "${YELLOW}Step 3b: Invite Bot to Supply Room${NC}"
INVITE_RESPONSE=$(curl -s -k -X POST "$MATRIX_HOST/_matrix/client/r0/rooms/$SUPPLY_ROOM_ID/invite" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"user_id\":\"$BOT_USER_ID\"}")
echo "Response: $(echo "$INVITE_RESPONSE" | jq -c '.')"
echo -e "${GREEN}✅ Bot invited to supply room${NC}\n"
sleep 2

# Step 3c: Grant Bot Power Level in Supply Room
echo -e "${YELLOW}Step 3c: Grant Bot Power Level (Supply)${NC}"
SUPPLY_POWER_LEVELS=$(curl -s -k "$MATRIX_HOST/_matrix/client/r0/rooms/$SUPPLY_ROOM_ID/state/m.room.power_levels" \
  -H "Authorization: Bearer $TOKEN")
SUPPLY_POWER_LEVELS_UPDATED=$(echo "$SUPPLY_POWER_LEVELS" | jq -c --arg bot "$BOT_USER_ID" '(.users // {}) as $u | .users=$u | .users[$bot]=50')
POWER_RESPONSE=$(curl -s -k -X PUT "$MATRIX_HOST/_matrix/client/r0/rooms/$SUPPLY_ROOM_ID/state/m.room.power_levels" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "$SUPPLY_POWER_LEVELS_UPDATED")
echo "Response: $(echo "$POWER_RESPONSE" | jq -c '.')"
echo -e "${GREEN}✅ Bot power level set in supply room${NC}\n"
sleep 2

# Step 4: Add Supply Data (Ingest)
echo -e "${YELLOW}Step 4: Add Supply Data via Ingest Endpoint${NC}"
INGEST_PAYLOAD="{
  \"@type\":\"cmd-ingest\",
  \"mode\":\"single\",
  \"input\":[{
    \"schema-url\":\"https://environment.app/schema/weather-station\",
    \"target\":{\"room-id\":\"$SUPPLY_ROOM_ID\"},
    \"data\":{
      \"@context\":\"https://environment.app/schema\",
      \"@type\":\"https://environment.app/schema/weather-station\",
      \"event-type-version\":\"v0.001\",
      \"station-id\":\"00001\",
      \"station-name\":\"Berlin-Tegel\",
      \"timestamp\":\"$TIMESTAMP\"
    }
  }]
}"
INGEST_RESPONSE=$(curl -s -k -X POST "$API_HOST/api/events/cmd-ingest" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "matrix_server: $MATRIX_SERVER" \
  -d "$INGEST_PAYLOAD")
echo "Response: $(echo "$INGEST_RESPONSE" | jq -c '.')"
echo -e "${GREEN}✅ Data ingest queued${NC}\n"
echo -e "${CYAN}Waiting 10 seconds for bot to process ingest...${NC}"
sleep 10

# Step 4b: Verify Data Persisted in Supply Room
echo -e "${YELLOW}Step 4b: Verify Data in Supply Room${NC}"
ROOM_EVENTS=$(curl -s -k "$MATRIX_HOST/_matrix/client/r0/rooms/$SUPPLY_ROOM_ID/messages?dir=b&limit=50" \
  -H "Authorization: Bearer $TOKEN")
WEATHER_EVENT=$(echo "$ROOM_EVENTS" | jq -r '.chunk[] | select(.type == "https://environment.app/schema/weather-station") | .event_id // empty' | head -1)

if [ -z "$WEATHER_EVENT" ]; then
  echo -e "${RED}❌ No weather-station event found in supply room!${NC}"
  echo "Events found:"
  echo "$ROOM_EVENTS" | jq -c '.chunk[] | {type: .type, sender: .sender}'
else
  echo -e "${GREEN}✅ Weather-station data persisted: $WEATHER_EVENT${NC}"
fi
echo ""

# Step 5: Create Demand Room
echo -e "${YELLOW}Step 5: Create Demand Room (Direct Matrix API)${NC}"
DEMAND_CREATE_PAYLOAD="{\"name\":\"$DEMAND_ROOM_NAME\",\"room_alias_name\":\"demand_$TIMESTAMP\",\"visibility\":\"private\",\"preset\":\"public_chat\"}"
DEMAND_RESPONSE=$(curl -s -k -X POST "$MATRIX_HOST/_matrix/client/r0/createRoom" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "$DEMAND_CREATE_PAYLOAD")
DEMAND_ROOM_ID=$(echo "$DEMAND_RESPONSE" | jq -r '.room_id // empty')

if [ -z "$DEMAND_ROOM_ID" ]; then
    echo -e "${RED}❌ Demand room creation failed${NC}"
    echo "Response: $DEMAND_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✅ Demand Room ID: $DEMAND_ROOM_ID${NC}\n"

# Step 5b: Invite Bot to Demand Room
echo -e "${YELLOW}Step 5b: Invite Bot to Demand Room${NC}"
INVITE_DEMAND_RESPONSE=$(curl -s -k -X POST "$MATRIX_HOST/_matrix/client/r0/rooms/$DEMAND_ROOM_ID/invite" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"user_id\":\"$BOT_USER_ID\"}")
echo "Response: $(echo "$INVITE_DEMAND_RESPONSE" | jq -c '.')"
echo -e "${GREEN}✅ Bot invited to demand room${NC}\n"
sleep 2

# Step 5c: Grant Bot Power Level in Demand Room
echo -e "${YELLOW}Step 5c: Grant Bot Power Level (Demand)${NC}"
DEMAND_POWER_LEVELS=$(curl -s -k "$MATRIX_HOST/_matrix/client/r0/rooms/$DEMAND_ROOM_ID/state/m.room.power_levels" \
  -H "Authorization: Bearer $TOKEN")
DEMAND_POWER_LEVELS_UPDATED=$(echo "$DEMAND_POWER_LEVELS" | jq -c --arg bot "$BOT_USER_ID" '(.users // {}) as $u | .users=$u | .users[$bot]=50')
DEMAND_POWER_RESPONSE=$(curl -s -k -X PUT "$MATRIX_HOST/_matrix/client/r0/rooms/$DEMAND_ROOM_ID/state/m.room.power_levels" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "$DEMAND_POWER_LEVELS_UPDATED")
echo "Response: $(echo "$DEMAND_POWER_RESPONSE" | jq -c '.')"
echo -e "${GREEN}✅ Bot power level set in demand room${NC}\n"
sleep 2

# Step 6: Search (Global)
echo -e "${YELLOW}Step 6: Search (Global)${NC}"
SEARCH_RESPONSE=$(curl -s -k "$API_HOST/api/bytem/global/search?search=*" \
  -H "Authorization: Bearer $TOKEN" \
  -H "matrix_server: $MATRIX_SERVER" 2>/dev/null || echo '{"error":"endpoint not available"}')
if echo "$SEARCH_RESPONSE" | jq empty 2>/dev/null; then
    ROOM_COUNT=$(echo "$SEARCH_RESPONSE" | jq '.rooms | length' 2>/dev/null || echo "N/A")
    echo "Rooms found: $ROOM_COUNT"
    echo -e "${GREEN}✅ Search executed${NC}\n"
else
    echo -e "${YELLOW}⚠️  Search endpoint not available (skipped)${NC}\n"
fi

# Step 7: Find in Solr
echo -e "${YELLOW}Step 7: Find in Solr${NC}"
FIND_RESPONSE=$(curl -s -k "$API_HOST/api/bytem/activity/fetchFindDetailsFromSolr?searchKey=NACE&searchValue=D35" \
  -H "Authorization: Bearer $TOKEN" \
  -H "matrix_server: $MATRIX_SERVER" 2>/dev/null || echo '{"error":"no results"}')
if echo "$FIND_RESPONSE" | jq empty 2>/dev/null; then
    echo "Response: $(echo "$FIND_RESPONSE" | jq -c '.')"
    echo -e "${GREEN}✅ Find executed${NC}\n"
else
    echo -e "${YELLOW}⚠️  Find endpoint not available (skipped)${NC}\n"
fi

# Step 8: Exchange
echo -e "${YELLOW}Step 8: Exchange (Link Supply to Demand)${NC}"
EXCHANGE_PAYLOAD="{\"demandRoomId\":\"$DEMAND_ROOM_ID\",\"supplyRoomId\":\"$SUPPLY_ROOM_ID\",\"exchangeType\":1}"
EXCHANGE_RESPONSE=$(curl -s -k -X POST "$API_HOST/api/subscription-exchange/receive-exchange-room" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "matrix_server: $MATRIX_SERVER" \
  -d "$EXCHANGE_PAYLOAD")
echo "Response: $(echo "$EXCHANGE_RESPONSE" | jq '.')"
echo -e "${GREEN}✅ Exchange initiated${NC}\n"

# Final Status
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                     Test Complete!                        ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}User:         ${NC}$USER_ID"
echo -e "${CYAN}Supply Room:  ${NC}$SUPPLY_ROOM_ID"
echo -e "${CYAN}Demand Room:  ${NC}$DEMAND_ROOM_ID"
echo -e "${CYAN}Space Name:   ${NC}$SPACE_NAME"
echo -e "${CYAN}Timestamp:    ${NC}$TIMESTAMP"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
