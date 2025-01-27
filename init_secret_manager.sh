#! /bin/bash

cd "$(dirname "$(readlink -f "$0")")" || {
  echo "Unable to go to parent folder of $0" >&2
  exit 1
}

exit_error() {
  echo "$1" >&2
  exit 1
}

declare -A packages=(
  ['gcp']='google-cloud-secret-manager google_crc32c pyyaml'
  ['aws']='boto3 pyyaml'
  ['common']='pyyaml'
)

declare -A dev_packages=(
  ['common']='toml autopep8'
)

if [ ! -d ./secret_manager ]; then
  poetry new secret-manager &&
    mv secret-manager/* ./ &&
    rmdir secret-manager
fi

poetry config --local virtualenvs.create true
poetry config --local virtualenvs.in-project true

# shellcheck disable=SC2068
poetry add ${packages[@]}
# shellcheck disable=SC2068
poetry add --group dev ${dev_packages[@]}

# Ensure to have toml installed
poetry run pip list | awk '{ print $1 }' | grep -qFx toml || poetry run pip install toml

# set tool.poetry.scripts.<secret manager> = <secret manager>.main:main in pyproject.toml
# set tool.poetry.authors = $USER in pyproject.toml
cat <<EOF | tr -d '\n' | xargs -0 -I {} poetry run python -c {}
import toml;
import os;
data = toml.load("pyproject.toml");

data.setdefault("tool", {}).setdefault("poetry", {}).setdefault("scripts", {})["secret-manager"] = "secret_manager.main:main";

toml.dump(data, open("pyproject.toml", "w"));
EOF

poetry install
