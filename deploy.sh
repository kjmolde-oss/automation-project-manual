#!/bin/bash
set -e # Stop script immediately on error

# --- 🔧 CONFIGURATION ---
DOCKERHUB_USERNAME=${DOCKERHUB_USERNAME:-"devopskarl"} 
IMAGE_NAME="${DOCKERHUB_USERNAME}/automation-project"
TIMESTAMP=$(date +%s)
VERSION="prod-${TIMESTAMP}"
VERSIONED_IMAGE="${IMAGE_NAME}:${VERSION}"

# --- 🛡️ PRE-FLIGHT CHECKS ---
echo "================================================================================"
echo "                        🛡️  RUNNING PRE-FLIGHT CHECKS"
echo "================================================================================"

# 1. Check for yq
if ! command -v yq &> /dev/null; then
    echo "❌ Error: 'yq' is not installed. Please install it (sudo snap install yq)."
    exit 1
fi

# 2. Clean up old artifact files to prevent 'zombie' data
rm -f image_name.txt new_live_version.txt

# 3. Disk Space Check (Stop if < 1.5GB free to prevent server crash)
AVAILABLE_SPACE=$(df /var/lib/docker --output=avail | tail -1)
if [ "$AVAILABLE_SPACE" -lt 1500000 ]; then
  echo "❌ CRITICAL: Low disk space! Clean up docker images before deploying."
  exit 1
fi

echo
echo "================================================================================"
echo "                    Build and Push (With CPU Throttling"
echo "================================================================================"
echo

echo -e "\n📦 [Step 1] Building and Pushing Docker Image..."
echo "ℹ️  Using 'nice' to lower CPU priority so live traffic isn't affected."

# Build with lower priority
nice -n 10 docker build -t "${IMAGE_NAME}:latest" .
docker tag "${IMAGE_NAME}:latest" "${VERSIONED_IMAGE}"

# Push
docker push "${IMAGE_NAME}:latest"
docker push "${VERSIONED_IMAGE}"

echo "✅ Image pushed: ${VERSIONED_IMAGE}"

echo
echo "================================================================================"
echo "                             DB Migration Check"
echo "================================================================================"
echo

echo -e "\n⚠️  [Step 2] DB Migration Check"
echo "------------------------------------------------------"
echo "Did you run any backward-compatible database migrations?"
echo "If this change requires a DB migration, run it now."
read -p "Press [Enter] to confirm and continue..."
echo "------------------------------------------------------"

echo
echo "================================================================================"
echo "                          Deploy to Idle Environment"
echo "================================================================================"
echo

echo -e "\n🚀 [Step 3] Deploying to Idle Environment..."

# Define paths
K8S_SERVICE_PATH="k8s/service.yaml"
DEPLOY_BLUE_PATH="k8s/deployment-blue.yaml"
DEPLOY_GREEN_PATH="k8s/deployment-green.yaml"

# Find LIVE version
LIVE_VERSION_LABEL=$(kubectl get svc automation-project-service -o=jsonpath='{.spec.selector.version}')

# Handle case where Service might be missing or broken
if [ -z "$LIVE_VERSION_LABEL" ]; then
    echo "⚠️  Warning: Could not detect live version. Defaulting to BLUE."
    LIVE_VERSION_LABEL="blue"
fi

echo "ℹ️  Current LIVE version is: $LIVE_VERSION_LABEL"

if [ "$LIVE_VERSION_LABEL" == "blue" ]; then
    TARGET_VERSION_LABEL="green"
    TARGET_DEPLOYMENT_PATH="$DEPLOY_GREEN_PATH"
else
    TARGET_VERSION_LABEL="blue"
    TARGET_DEPLOYMENT_PATH="$DEPLOY_BLUE_PATH"
fi

echo "🎯 Target IDLE environment is: $TARGET_VERSION_LABEL"

# --- CRITICAL FIX: Ensure Internal Networking Exists ---
echo "🔧 Ensuring internal services exist for testing..."
kubectl apply -f k8s/service-blue-internal.yaml
kubectl apply -f k8s/service-green-internal.yaml

# Update YAML with new Image
sed -i '1s/^\xEF\xBB\xBF//' "${TARGET_DEPLOYMENT_PATH}"
yq e ".spec.template.spec.containers[0].image = \"${VERSIONED_IMAGE}\"" -i "${TARGET_DEPLOYMENT_PATH}"

# Apply and Wait
kubectl apply -f "${TARGET_DEPLOYMENT_PATH}"
echo "⏳ Waiting for rollout of ${TARGET_VERSION_LABEL}..."
kubectl rollout status deployment/automation-project-${TARGET_VERSION_LABEL}

echo "✅ ${TARGET_VERSION_LABEL} is ready for testing."

echo
echo "================================================================================"
echo "                              Automated Smoke Tests"
echo "================================================================================"
echo
echo -e "\n🧪 [Step 4] Running Smoke Tests..."

if [ "$TARGET_VERSION_LABEL" == "blue" ]; then
    TEST_URL="http://test-blue.karl.com"
    TEST_INGRESS_YAML="k8s/ingress-test-blue.yaml"
else
    TEST_URL="http://test-green.karl.com"
    TEST_INGRESS_YAML="k8s/ingress-test-green.yaml"
fi

# Apply Test Ingress
sed -i '1s/^\xEF\xBB\xBF//' "${TEST_INGRESS_YAML}"
kubectl apply -f "${TEST_INGRESS_YAML}"
echo "⏳ Waiting 5s for Ingress to propagate..."
sleep 5

# Run Test Script
chmod +x k8s/smoke-test.sh
bash k8s/smoke-test.sh "${TEST_URL}"

echo "✅ Smoke tests passed!"

echo
echo "================================================================================"
echo "                               Promote to Live"
echo "================================================================================"
echo

echo -e "\n🛑 [Step 5] Ready to Promote to LIVE?"
echo "Current Live: $LIVE_VERSION_LABEL"
echo "New Live:     $TARGET_VERSION_LABEL"
read -p "Press [Enter] to SWITCH TRAFFIC (or Ctrl+C to cancel)..."

HPA_PATH="k8s/hpa.yaml"
LIVE_INGRESS_PATH="k8s/ingress-live.yaml"
NEW_LIVE_DEPLOYMENT="automation-project-${TARGET_VERSION_LABEL}"

echo "🔄 Switching Service to ${TARGET_VERSION_LABEL}..."

# Update Service
sed -i '1s/^\xEF\xBB\xBF//' "${K8S_SERVICE_PATH}"
yq e ".spec.selector.version = \"${TARGET_VERSION_LABEL}\"" -i "${K8S_SERVICE_PATH}"
kubectl apply -f "${K8S_SERVICE_PATH}"

# Update HPA
sed -i '1s/^\xEF\xBB\xBF//' "${HPA_PATH}"
yq e ".spec.scaleTargetRef.name = \"${NEW_LIVE_DEPLOYMENT}\"" -i "${HPA_PATH}"
kubectl apply -f "${HPA_PATH}"

# Update Ingress
sed -i '1s/^\xEF\xBB\xBF//' "${LIVE_INGRESS_PATH}"
kubectl apply -f "${LIVE_INGRESS_PATH}"

echo "✅ Cut-over complete! Waiting 30s for old connections to drain..."
sleep 30

echo
echo "================================================================================"
echo "                             POST-FLIGHT: Cleanup"
echo "================================================================================"
echo

echo "🧹 Cleaning up old Docker images to save disk space..."
docker image prune -f --filter "until=24h"

echo
echo "--------------------------------------------------------------------------------"
echo "                🎉 DEPLOYMENT COMPLETE! Live is now: ${TARGET_VERSION_LABEL}"
echo "--------------------------------------------------------------------------------"
echo
