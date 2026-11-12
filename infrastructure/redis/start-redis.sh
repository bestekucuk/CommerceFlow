#!/bin/sh
# Starts Redis with ACL users built from environment variables (no passwords in files).
# - default user disabled
# - one user per owning service, restricted to its key prefix (<service>:*)
# - monitoring user for the exporter and health checks (read-only server commands)
set -eu

: "${PRODUCT_REDIS_PASSWORD:?}" "${PRICING_REDIS_PASSWORD:?}" "${MONITORING_REDIS_PASSWORD:?}"

ACL=/tmp/users.acl
umask 077
cat > "$ACL" <<EOF
user default off
user product-service on >${PRODUCT_REDIS_PASSWORD} ~product:* &product:* +@all -@admin -@dangerous
user pricing-service on >${PRICING_REDIS_PASSWORD} ~pricing:* &pricing:* +@all -@admin -@dangerous
user monitoring on >${MONITORING_REDIS_PASSWORD} ~* -@all +@connection +info +ping +config|get +client|list +slowlog|get +latency|latest +memory|stats +dbsize +select +scan +type +strlen +llen +scard +zcard +hlen +xlen
EOF

exec redis-server --aclfile "$ACL" --appendonly no --save ""
