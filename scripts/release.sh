#!/usr/bin/env bash

set -euo pipefail

if [[ "${RELEASE_DEBUG:-0}" == "1" ]]; then
  set -x
fi

usage() {
  echo "Usage: $0 [version]"
  echo "Examples:"
  echo "  $0        # auto bump patch version"
  echo "  $0 1.0.2  # release a specific version"
}

log() {
  echo "[release] $*"
}

get_repo_slug() {
  local remote_url
  remote_url="$(git remote get-url origin)"
  remote_url="${remote_url%.git}"
  remote_url="${remote_url#git@github.com:}"
  remote_url="${remote_url#https://github.com/}"
  remote_url="${remote_url#http://github.com/}"
  echo "$remote_url"
}

run_step() {
  local description="$1"
  shift
  log "$description"
  "$@"
  log "done: $description"
}

prepend_changelog_entry() {
  local version="$1"
  local today
  today="$(date '+%Y-%m-%d')"

  if grep -q "^## \[$version\]" CHANGELOG.md; then
    log "CHANGELOG already contains $version"
    return
  fi

  log "adding CHANGELOG entry for $version"
  tmp_file="$(mktemp)"
  {
    echo "# Changelog"
    echo
    echo "All notable changes to this project will be documented in this file."
    echo
    echo "The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),"
    echo "and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)."
    echo
    echo "## [$version] - $today"
    echo
    echo "### Changed"
    echo
    echo "- Prepare release $version."
    echo
    tail -n +7 CHANGELOG.md
  } > "$tmp_file"
  mv "$tmp_file" CHANGELOG.md
  log "done: adding CHANGELOG entry for $version"
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

log "current version: $CURRENT_VERSION"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Working tree is not clean. Commit or stash your changes before releasing."
  exit 1
fi

run_step "fetching origin" git fetch origin
run_step "checking out main" git checkout main
run_step "pulling latest main" git pull --ff-only origin main

if [[ $# -eq 1 ]]; then
  VERSION="$1"
else
  MAJOR="${BASH_REMATCH[1]}"
  MINOR="${BASH_REMATCH[2]}"
  PATCH="${BASH_REMATCH[3]}"
  VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"
fi

TAG="v$VERSION"
REPO_SLUG="$(get_repo_slug)"
log "target version: $VERSION"
log "target tag: $TAG"

if [[ "$CURRENT_VERSION" != "$VERSION" ]]; then
  log "updating pubspec.yaml version..."
  sed -i.bak "s/^version: .*/version: $VERSION/" pubspec.yaml
  rm -f pubspec.yaml.bak
  log "done: updating pubspec.yaml version"
fi

prepend_changelog_entry "$VERSION"

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists locally"
  exit 1
fi

log "committing release version bump..."
git add pubspec.yaml CHANGELOG.md
git commit -m "Release $VERSION"
log "done: committing release version bump"

run_step "pushing main to origin" git push origin main
run_step "creating tag $TAG" git tag "$TAG"
run_step "pushing tag $TAG" git push origin "$TAG"

log "released $VERSION and pushed $TAG"
log "GitHub Actions publish workflow should start now."
log "GitHub Actions: https://github.com/$REPO_SLUG/actions"
log "Release tag: https://github.com/$REPO_SLUG/releases/tag/$TAG"
log "pub.dev package: https://pub.dev/packages/tgortcflutter"
log "pub.dev versions: https://pub.dev/packages/tgortcflutter/versions"
