#!/usr/bin/env bash
# Creates (or updates retention of) every topic listed in topics.csv. Idempotent; runs in
# the kafka-init one-shot container. Broker auto topic creation is disabled, so topics
# exist only if they are declared here.
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-kafka:29092}"
BIN=/opt/kafka/bin
FILE=/etc/commerceflow/topics.csv

created=0
updated=0
while IFS=, read -r name partitions retention kind; do
    case "$name" in ''|'#'*) continue ;; esac
    if "$BIN/kafka-topics.sh" --bootstrap-server "$BOOTSTRAP" --describe --topic "$name" > /dev/null 2>&1; then
        "$BIN/kafka-configs.sh" --bootstrap-server "$BOOTSTRAP" --alter --entity-type topics \
            --entity-name "$name" --add-config "retention.ms=${retention}" > /dev/null
        updated=$((updated + 1))
    else
        "$BIN/kafka-topics.sh" --bootstrap-server "$BOOTSTRAP" --create --if-not-exists \
            --topic "$name" --partitions "$partitions" --replication-factor 1 \
            --config "retention.ms=${retention}" --config cleanup.policy=delete > /dev/null
        echo "created $name ($kind, partitions=$partitions, retention.ms=$retention)"
        created=$((created + 1))
    fi
done < "$FILE"
echo "topics: created=$created updated=$updated"
