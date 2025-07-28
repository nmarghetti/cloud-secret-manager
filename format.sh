#! /bin/sh

cd "$(dirname "$(readlink -f "$0")")" || {
  echo "Unable to go to parent folder of $0" >&2
  exit 1
}

poetry run isort cloud_secret_manager tests
poetry run autopep8 --in-place -a -r .
