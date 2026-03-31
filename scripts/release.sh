#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 1.0.2"
  exit 1
fi

VERSION="$1"
TAG="v$VERSION"

CURRENT_VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}')"

if [[ "$CURRENT_VERSION" != "$VERSION" ]]; then
  echo "pubspec.yaml version is $CURRENT_VERSION, expected $VERSION"
  echo "Update pubspec.yaml before running release.sh"
  exit 1
fi

git fetch origin
git checkout main
git pull --ff-only origin main

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists locally"
  exit 1
fi

git tag "$TAG"
git push origin "$TAG"

echo "Pushed $TAG. GitHub Actions publish workflow should start now."
