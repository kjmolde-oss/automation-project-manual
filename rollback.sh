#!/bin/bash
set -e

# ======================================================
#           Emergency Rollback Script
# ======================================================

echo "--------------------------------------------------"
echo "              EMERGENCY ROLLBACK"
echo "--------------------------------------------------"

K8S_SERVICE_PATH="k8s/service.yaml"
HPA_PATH="k8s/hpa.yaml"

echo
echo "=================================================="
echo "               FIND LIVE VERSION"
echo "=================================================="

LIVE_VERSION_LABEL=$(kubectl get svc automation-project-service -o=jsonpath='{.spec.selector.version}')
echo "Live version detected: $LIVE_VERSION_LABEL"

echo
echo "=================================================="
echo "           DETERMINE ROLLBACK TARGET"
echo "=================================================="

if [ "$LIVE_VERSION_LABEL" = "blue" ]; then
    ROLLBACK_VERSION_LABEL="green"
else
    ROLLBACK_VERSION_LABEL="blue"
fi

ROLLBACK_DEPLOYMENT="automation-project-${ROLLBACK_VERSION_LABEL}"

echo "Rollback will switch traffic from: $LIVE_VERSION_LABEL"
echo "Rollback target deployment: $ROLLBACK_VERSION_LABEL"

echo
echo "=================================================="
echo "                UPDATING SERVICE"
echo "=================================================="

# Remove BOM if present
sed -i '1s/^\xEF\xBB\xBF//' "$K8S_SERVICE_PATH"

yq e ".spec.selector.version = \"${ROLLBACK_VERSION_LABEL}\"" -i "$K8S_SERVICE_PATH"
kubectl apply -f "$K8S_SERVICE_PATH"

echo
echo "=================================================="
echo "                  UPDATING HPA"
echo "=================================================="

sed -i '1s/^\xEF\xBB\xBF//' "$HPA_PATH"

yq e ".spec.scaleTargetRef.name = \"${ROLLBACK_DEPLOYMENT}\"" -i "$HPA_PATH"
kubectl apply -f "$HPA_PATH"

echo
echo "Rollback complete. Traffic is now routed to: $ROLLBACK_VERSION_LABEL"
echo "--------------------------------------------------"
