#!/usr/bin/env bash

set -euo pipefail

SCRIPT_VERSION="example-web-template-v1"

REGISTRY="CHANGE_ME_REGISTRY"
IMAGE="$REGISTRY/CHANGE_ME_WEB_IMAGE"

ATLAS_HOST="CHANGE_ME_SSH_HOST"
ATLAS_PORT="CHANGE_ME_SSH_PORT"
ATLAS_USER="CHANGE_ME_SSH_USER"

NAMESPACE="CHANGE_ME_NAMESPACE"
DEPLOYMENT="CHANGE_ME_WEB_DEPLOYMENT"
CONTAINER="web"
EXPECTED_CLUSTER_IP="CHANGE_ME_WEB_CLUSTER_IP"
PRODUCTION_URL="https://CHANGE_ME_WEB_DOMAIN"

# Configure the values above before running. Runtime env stays on Kubernetes.
for config_name in REGISTRY IMAGE ATLAS_HOST ATLAS_PORT ATLAS_USER NAMESPACE DEPLOYMENT CONTAINER EXPECTED_CLUSTER_IP PRODUCTION_URL; do
  config_value="${!config_name}"
  if [[ -z "$config_value" || "$config_value" == *CHANGE_ME* ]]; then
    echo "ERROR: configure $config_name before build/deploy." >&2
    exit 1
  fi
done
if [[ ! -f "frontend/Dockerfile" ]]; then
  echo "ERROR: run from the project root containing frontend/Dockerfile." >&2
  exit 1
fi

echo "=== EXAMPLE Web Release ==="
echo "Script version: $SCRIPT_VERSION"
echo

# 1. Git safety check

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: Git working tree is not clean."
  echo
  git status --short
  echo
  echo "Commit or stash your changes before production deployment."
  exit 1
fi

TAG="$(git rev-parse --short HEAD)"
BRANCH="$(git branch --show-current)"

echo "Branch : $BRANCH"
echo "Commit : $TAG"
echo

# 2. Build + push

echo "Building:"
echo "  $IMAGE:$TAG"
echo

docker buildx build \
  --platform linux/amd64 \
  -t "$IMAGE:$TAG" \
  --push \
  ./frontend

echo
echo "Build and push completed."
echo

# 3. Resolve immutable digest

DIGEST="$(
  docker buildx imagetools inspect "$IMAGE:$TAG" \
    | awk '/^Digest:/ {print $2; exit}'
)"

if [[ ! "$DIGEST" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo "ERROR: Could not determine immutable image digest."
  exit 1
fi

IMAGE_REF="$IMAGE@$DIGEST"

echo "Immutable production image:"
echo
echo "  $IMAGE_REF"
echo

# 4. Human production gate

read -r -p "Deploy this image to EXAMPLE production? [y/N] " ANSWER

case "$ANSWER" in
  y|Y|yes|YES)
    ;;
  *)
    echo
    echo "Deployment cancelled."
    echo "Image remains available in Registry:"
    echo "  $IMAGE:$TAG"
    echo "  $IMAGE_REF"
    exit 0
    ;;
esac

echo
echo "Deploying to ATLAS..."
echo

# 5. Kubernetes deployment + internal Service smoke

ssh -t \
  -p "$ATLAS_PORT" \
  "$ATLAS_USER@$ATLAS_HOST" \
  "set -euo pipefail

  sudo kubectl set image deployment/$DEPLOYMENT $CONTAINER='$IMAGE_REF' -n $NAMESPACE
  sudo kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=180s

  echo
  echo 'Live image:'
  LIVE_IMAGE=\$(sudo kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].image}')
  echo \"\$LIVE_IMAGE\"

  if [ \"\$LIVE_IMAGE\" != '$IMAGE_REF' ]; then
    echo 'ERROR: live image does not match requested image' >&2
    exit 1
  fi

  echo
  echo 'Testing internal EXAMPLE Web Service...'

  INTERNAL_OK=0
  for i in \$(seq 1 10); do
    CODE=\$(curl -sS --connect-timeout 3 --max-time 10 -o /dev/null -w '%{http_code}' 'http://$EXPECTED_CLUSTER_IP:80/' || true)

    if [ \"\$CODE\" = '200' ]; then
      echo \"Internal smoke: PASS (HTTP 200, attempt \$i/10)\"
      INTERNAL_OK=1
      break
    fi

    echo \"Internal smoke attempt \$i/10: HTTP \${CODE:-connection-error}\"
    [ \"\$i\" -eq 10 ] || sleep 2
  done

  if [ \"\$INTERNAL_OK\" != '1' ]; then
    echo 'ERROR: internal EXAMPLE Web Service smoke failed after 10 attempts' >&2
    exit 1
  fi"

# 6. External smoke test with bounded retry

echo
echo "Testing production..."
echo

PUBLIC_OK=0
for i in {1..10}; do
  CODE="$(curl -sS --connect-timeout 5 --max-time 15 -o /dev/null -w '%{http_code}' "$PRODUCTION_URL/" || true)"

  if [[ "$CODE" == "200" ]]; then
    echo "EXAMPLE Web production smoke test: PASS (HTTP 200, attempt $i/10)"
    PUBLIC_OK=1
    break
  fi

  echo "Production smoke attempt $i/10: HTTP ${CODE:-connection-error}"
  [[ "$i" -eq 10 ]] || sleep 3
done

if [[ "$PUBLIC_OK" != "1" ]]; then
  echo "ERROR: EXAMPLE Web production smoke failed after 10 attempts." >&2
  exit 1
fi

echo
echo "Release complete:"
echo "  Commit : $TAG"
echo "  Image  : $IMAGE_REF"
