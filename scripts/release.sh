#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 [version]"
  echo "Examples:"
  echo "  $0        # auto bump patch version"
  echo "  $0 1.0.2  # release a specific version"
}

CURRENT_VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}')"

if [[ $# -gt 1 ]]; then
  usage
  exit 1
fi

if ! [[ "$CURRENT_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "Current version '$CURRENT_VERSION' is not a simple semantic version (x.y.z)"
  echo "Please update pubspec.yaml manually and rerun with an explicit version"
  exit 1
fi

git fetch origin
git checkout main
git pull --ff-only origin main

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Working tree is not clean. Commit or stash your changes before releasing."
  exit 1
fi

if [[ $# -eq 1 ]]; then
  VERSION="$1"
else
  MAJOR="${BASH_REMATCH[1]}"
  MINOR="${BASH_REMATCH[2]}"
  PATCH="${BASH_REMATCH[3]}"
  VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"
fi

TAG="v$VERSION"

if [[ "$CURRENT_VERSION" != "$VERSION" ]]; then
  sed -i.bak "s/^version: .*/version: $VERSION/" pubspec.yaml
  rm -f pubspec.yaml.bak
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists locally"
  exit 1
fi

git add pubspec.yaml
git commit -m "Release $VERSION"
git push origin main

git tag "$TAG"
git push origin "$TAG"

echo "Released $VERSION and pushed $TAG. GitHub Actions publish workflow should start now."
