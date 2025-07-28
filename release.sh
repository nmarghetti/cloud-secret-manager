#! /bin/sh

cd "$(dirname "$(readlink -f "$0")")" || {
  echo "Unable to go to parent folder of $0" >&2
  exit 1
}

exit_error () {
  echo "$1" >&2
  exit 1
}

# Check if we are on the main branch and there are no uncommitted changes
[ "$(git symbolic-ref --short HEAD)" = "main" ] || exit_error "You are not on the main branch, please switch to main"
[ -z "$(git status --porcelain)" ] || exit_error "There are uncommitted changes / untracked files. Please commit or stash them before releasing."

# Get project version from pyproject.toml
PROJECT_VERSION="$(cat <<EOF | tr -d '\n' | xargs -0 -I {} poetry run python -c {}
import toml;
data = toml.load("pyproject.toml");

print(data.get("project", {}).get("version", ""))
EOF
)"
[ -n "$PROJECT_VERSION" ] || exit_error "Unable to get project version from pyproject.toml"

# Get poetry version from pyproject.toml
PROJECT_VERSION_POETRY="$(cat <<EOF | tr -d '\n' | xargs -0 -I {} poetry run python -c {}
import toml;
data = toml.load("pyproject.toml");

print(data.get("tool", {}).get("poetry", {}).get("version", ""))
EOF
)"
[ -n "$PROJECT_VERSION_POETRY" ] || exit_error "Unable to get project version from pyproject.toml"

# Check if project version and poetry version match
[ "$PROJECT_VERSION" = "$PROJECT_VERSION_POETRY" ] || exit_error "Project version and poetry version do not match in pyproject.toml, please align"

# Check if git tag already exists
if git tag | grep -qFx "$PROJECT_VERSION"; then
  exit_error "Git tag $PROJECT_VERSION already exists, please upgrade version in pyproject.toml"
fi

# Get pypi token from ~/.pypirc
PYPI_TOKEN="$(git config -f ~/.pypirc --get pypi.password | xargs printf)"
[ -n "$PYPI_TOKEN" ] || exit_error "Unable to get pypi token from ~/.pypirc"

# Release to pypi
echo "Releasing version $PROJECT_VERSION"
poetry config pypi-token.pypi "$PYPI_TOKEN" || exit_error "Unable to set pypi token"
poetry config repositories.pypi https://upload.pypi.org/legacy/ || exit_error "Unable to set pypi repository"
poetry build || exit_error "Unable to build"
poetry publish --repository pypi || exit_error "Unable to publish to pypi"
git tag "$PROJECT_VERSION" || exit_error "Unable to tag the release"
git push --atomic origin main "$PROJECT_VERSION" || exit_error "Unable to push the release tag"
echo "Released version $PROJECT_VERSION"
