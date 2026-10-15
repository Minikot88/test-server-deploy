#!/usr/bin/env bash

set -euo pipefail

SCRIPT_VERSION="example-api-template-v1"

REGISTRY="CHANGE_ME_REGISTRY"
IMAGE="$REGISTRY/CHANGE_ME_API_IMAGE"

ATLAS_HOST="CHANGE_ME_SSH_HOST"
ATLAS_PORT="CHANGE_ME_SSH_PORT"
ATLAS_USER="CHANGE_ME_SSH_USER"

NAMESPACE="CHANGE_ME_NAMESPACE"
DEPLOYMENT="CHANGE_ME_API_DEPLOYMENT"
CONTAINER="api"

# Name and key NAMES only. Values are supplied by this Secret on Kubernetes.
RUNTIME_SECRET="CHANGE_ME_API_RUNTIME_SECRET"
# For a real app, list the key names it needs, e.g. DATABASE_URL and JWT_SECRET.
# The teaching API has no database/secret dependency, so its list is empty.
REQUIRED_SECRET_KEYS=()

INTERNAL_HEALTH_URL="http://CHANGE_ME_API_CLUSTER_IP:18787/health"
HEALTH_URL="https://CHANGE_ME_API_DOMAIN/health"

# Configure the values above before running. Runtime env stays on Kubernetes.
for config_name in REGISTRY IMAGE ATLAS_HOST ATLAS_PORT ATLAS_USER NAMESPACE DEPLOYMENT CONTAINER RUNTIME_SECRET INTERNAL_HEALTH_URL HEALTH_URL; do
  config_value="${!config_name}"
  if [[ -z "$config_value" || "$config_value" == *CHANGE_ME* ]]; then
    echo "ERROR: configure $config_name before build/deploy." >&2
    exit 1
  fi
done
[[ "$RUNTIME_SECRET" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]] || {
  echo "ERROR: RUNTIME_SECRET must be a Kubernetes Secret name." >&2; exit 1;
}
for required_key in "${REQUIRED_SECRET_KEYS[@]}"; do
  [[ "$required_key" =~ ^[A-Za-z0-9_.-]+$ && "$required_key" != *CHANGE_ME* ]] || {
    echo "ERROR: REQUIRED_SECRET_KEYS must contain configured key names only." >&2; exit 1;
  }
done
if [[ ! -f "backend/Dockerfile" ]]; then
  echo "ERROR: run from the project root containing backend/Dockerfile." >&2
  exit 1
fi

echo "=== EXAMPLE API Release ==="
echo "Script version: $SCRIPT_VERSION"
echo

# --------------------------------------------------
# 1. Git safety checks
# --------------------------------------------------

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: Git working tree is not clean."
  echo
  git status --short
  echo
  echo "Commit or stash your changes before production deployment."
  exit 1
fi

BRANCH="$(git branch --show-current)"
TAG="$(git rev-parse --short HEAD)"

echo "Refreshing origin/main..."
git fetch origin --quiet

LOCAL_HEAD="$(git rev-parse HEAD)"
REMOTE_HEAD="$(git rev-parse origin/main)"

echo "Branch : $BRANCH"
echo "Commit : $TAG"
echo

if [[ "$BRANCH" != "main" ]]; then
  echo "ERROR: Production deployment must be run from main."
  exit 1
fi

if [[ "$LOCAL_HEAD" != "$REMOTE_HEAD" ]]; then
  echo "ERROR: Local HEAD does not match origin/main."
  echo
  echo "Push or synchronize main before production deployment."
  echo
  echo "Local : $LOCAL_HEAD"
  echo "Remote: $REMOTE_HEAD"
  exit 1
fi

echo "Remote traceability check: PASS"
echo

# --------------------------------------------------
# 2. Build + push
# --------------------------------------------------

echo "Building:"
echo "  $IMAGE:$TAG"
echo

docker buildx build \
  --platform linux/amd64 \
  -t "$IMAGE:$TAG" \
  --push \
  ./backend

echo
echo "Build and push completed."
echo

# --------------------------------------------------
# 3. Resolve immutable digest
# --------------------------------------------------

DIGEST="$(
  docker buildx imagetools inspect "$IMAGE:$TAG" \
    | awk '/^Digest:/ {print $2; exit}'
)"

if [[ ! "$DIGEST" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo "ERROR: Could not determine a valid sha256 image digest."
  echo "Resolved digest: ${DIGEST:-<empty>}"
  exit 1
fi

IMAGE_REF="$IMAGE@$DIGEST"

echo "Immutable production image:"
echo
echo "  $IMAGE_REF"
echo

# --------------------------------------------------
# 4. Human production gate
# --------------------------------------------------

read -r -p "Deploy this API image to EXAMPLE production? [y/N] " ANSWER

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

# --------------------------------------------------
# 5. Deploy on ATLAS + internal health verification
# --------------------------------------------------

echo
echo "Connecting to ATLAS..."
echo

ssh -tt \
  -p "$ATLAS_PORT" \
  "$ATLAS_USER@$ATLAS_HOST" \
  "set -euo pipefail

  sudo -v

  echo 'Checking runtime Secret references and required key names...'
  FIRST_CONTAINER=\$(sudo kubectl get deployment '$DEPLOYMENT' -n '$NAMESPACE' -o jsonpath='{.spec.template.spec.containers[0].name}')
  if [ \"\$FIRST_CONTAINER\" != '$CONTAINER' ]; then
    echo 'ERROR: configured API container must be the first Deployment container.' >&2
    exit 1
  fi
  SECRET_KEYS=\$(sudo kubectl get secret '$RUNTIME_SECRET' -n '$NAMESPACE' -o go-template='{{range \$key, \$value := .data}}{{printf \"%s\\n\" \$key}}{{end}}')
  SECRET_REFS=\$(sudo kubectl get deployment '$DEPLOYMENT' -n '$NAMESPACE' -o jsonpath='{.spec.template.spec.containers[0].envFrom[*].secretRef.name}')
  KEY_REFS=\$(sudo kubectl get deployment '$DEPLOYMENT' -n '$NAMESPACE' -o jsonpath='{.spec.template.spec.containers[0].env[*].valueFrom.secretKeyRef.name}')
  SECRET_FOUND=0
  for SECRET_NAME in \$SECRET_REFS \$KEY_REFS; do
    if [ \"\$SECRET_NAME\" = '$RUNTIME_SECRET' ]; then SECRET_FOUND=1; fi
  done
  if [ \"\$SECRET_FOUND\" != '1' ]; then
    echo 'ERROR: configured API container does not reference the runtime Secret.' >&2
    exit 1
  fi
  for REQUIRED_KEY in ${REQUIRED_SECRET_KEYS[*]}; do
    if ! printf '%s\\n' \"\$SECRET_KEYS\" | grep -Fxq \"\$REQUIRED_KEY\"; then
      echo \"ERROR: required runtime Secret key is missing: \$REQUIRED_KEY\" >&2
      exit 1
    fi
  done
  echo 'Runtime Secret preflight: PASS (values not displayed)'

  echo
  echo 'Current production image:'
  sudo kubectl get deployment '$DEPLOYMENT' -n '$NAMESPACE' -o jsonpath='{.spec.template.spec.containers[0].image}'
  echo

  echo
  echo 'New production image:'
  echo '  $IMAGE_REF'
  echo

  sudo kubectl set image deployment/'$DEPLOYMENT' '$CONTAINER=$IMAGE_REF' -n '$NAMESPACE'

  echo
  echo 'Waiting for rollout...'
  sudo kubectl rollout status deployment/'$DEPLOYMENT' -n '$NAMESPACE' --timeout=180s

  LIVE_IMAGE=\$(sudo kubectl get deployment '$DEPLOYMENT' -n '$NAMESPACE' -o jsonpath='{.spec.template.spec.containers[0].image}')

  echo
  echo 'Live image:'
  echo \"  \$LIVE_IMAGE\"

  if [ \"\$LIVE_IMAGE\" != '$IMAGE_REF' ]; then
    echo 'ERROR: live image does not match requested image.' >&2
    echo 'Expected: $IMAGE_REF' >&2
    echo \"Actual  : \$LIVE_IMAGE\" >&2
    exit 1
  fi

  echo 'Live image verification: PASS'

  echo
  echo 'Testing internal EXAMPLE API health...'

  INTERNAL_OK=0
  for i in \$(seq 1 10); do
    CODE=\$(curl -sS --connect-timeout 5 --max-time 10 -o /dev/null -w '%{http_code}' '$INTERNAL_HEALTH_URL' || true)

    if [ \"\$CODE\" = '200' ]; then
      echo \"Internal health: PASS (HTTP 200, attempt \$i/10)\"
      INTERNAL_OK=1
      break
    fi

    echo \"Internal health attempt \$i/10: HTTP \${CODE:-connection-error}\"
    [ \"\$i\" -eq 10 ] || sleep 3
  done

  if [ \"\$INTERNAL_OK\" != '1' ]; then
    echo 'ERROR: internal EXAMPLE API health check failed after 10 attempts.' >&2
    exit 1
  fi"

# --------------------------------------------------
# 6. Public production health check
# --------------------------------------------------

echo
echo "Testing production API..."
echo

HEALTH_OK=0

for ATTEMPT in {1..12}; do
  echo "Health check attempt $ATTEMPT/12..."

  CODE="$(curl -sS --connect-timeout 10 --max-time 20 -o /dev/null -w '%{http_code}' "$HEALTH_URL" || true)"
  if [[ "$CODE" == "200" ]]; then
    HEALTH_OK=1
    echo "Public health: PASS (HTTP 200)"
    break
  fi

  echo "Public health: HTTP ${CODE:-connection-error}"
  echo "API not ready yet. Retrying in 5 seconds..."
  sleep 5
done

if [[ "$HEALTH_OK" -ne 1 ]]; then
  echo
  echo "ERROR: Production API health check failed after retries."
  echo
  echo "Rollback:"
  echo "  ssh -t -p $ATLAS_PORT $ATLAS_USER@$ATLAS_HOST"
  echo "  sudo kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE"
  echo "  sudo kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE"
  exit 1
fi

echo
echo "EXAMPLE API production health check: PASS"

echo
echo "Release complete:"
echo "  Commit : $TAG"
echo "  Image  : $IMAGE_REF"
