#!/usr/bin/env bash

set -eu
set -o pipefail

readonly PROGDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BUILDERDIR="$(cd "${PROGDIR}/.." && pwd)"
readonly BIN_DIR="${BUILDERDIR}/.bin"

# shellcheck source=SCRIPTDIR/.util/tools.sh
source "${PROGDIR}/.util/tools.sh"

# shellcheck source=SCRIPTDIR/.util/print.sh
source "${PROGDIR}/.util/print.sh"

function main() {
  local name token
  token=""

  while [[ "${#}" != 0 ]]; do
    case "${1}" in
      --help|-h)
        shift 1
        usage
        exit 0
        ;;

      --name|-n)
        name="${2}"
        shift 2
        ;;

      --token|-t)
        token="${2}"
        shift 2
        ;;

      "")
        # skip if the argument is empty
        shift 1
        ;;

      *)
        util::print::error "unknown argument \"${1}\""
    esac
  done

  if [[ ! -d "${BUILDERDIR}/smoke" ]]; then
      util::print::warn "** WARNING  No Smoke tests **"
  fi

  if [[ -z "${name:-}" ]]; then
    name="testbuilder"
  fi

  local registryPort registryPid localRegistry imageName

  local push_builder_to_local_registry
  if [ -f "$(dirname "${BASH_SOURCE[0]}")/options.json" ]; then
    push_builder_to_local_registry="$(jq -r '.push_builder_to_local_registry //false' "$(dirname "${BASH_SOURCE[0]}")/options.json")"
  else
    push_builder_to_local_registry="false"
  fi

  tools::install "${token}"

  builder::create "${name}"

  if [ "${push_builder_to_local_registry}" == "true" ]; then
    registryPort=$(get::random::port)
    registryPid=$(local::registry::start "$registryPort")
    localRegistry="127.0.0.1:$registryPort"
    docker tag "$name" "$localRegistry/$name"
    docker push "$localRegistry/$name"
    imageName="$localRegistry/$name"
  else
    imageName="$name"
  fi
  tests::run $imageName

  kill $registryPid
}

function usage() {
  cat <<-USAGE
smoke.sh [OPTIONS]

Runs the smoke test suite.

OPTIONS
  --help        -h         prints the command usage
  --name <name> -n <name>  sets the name of the builder that is built for testing
  --token <token>          Token used to download assets from GitHub (e.g. jam, pack, etc) (optional)
USAGE
}

function tools::install() {
  local token
  token="${1}"

  util::tools::crane::install \
    --directory "${BIN_DIR}"

  util::tools::pack::install \
    --directory "${BIN_DIR}" \
    --token "${token}"
}

function builder::create() {
  local name
  name="${1}"

  util::print::title "Creating builder..."
  pack builder create "${name}" --config "${BUILDERDIR}/builder.toml"
}

function image::pull::lifecycle() {
  local name lifecycle_image
  name="${1}"

  lifecycle_image="index.docker.io/buildpacksio/lifecycle:$(
    pack builder inspect "${name}" --output json \
      | jq -r '.local_info.lifecycle.version'
  )"

  util::print::title "Pulling lifecycle image..."
  docker pull "${lifecycle_image}"
}

function tests::run() {
  local name
  name="$1"

  util::print::title "Run Builder Smoke Tests"

  export CGO_ENABLED=0
  testout=$(mktemp)
  pushd "${BUILDERDIR}" > /dev/null
    if GOMAXPROCS="${GOMAXPROCS:-4}" go test -count=1 -timeout 0 ./smoke/... -v -run Smoke --name "${name}" | tee "${testout}"; then
      util::tools::tests::checkfocus "${testout}"
      util::print::success "** GO Test Succeeded **"
    else
      util::print::error "** GO Test Failed **"
    fi
  popd > /dev/null
}

# Returns a random unused port
function get::random::port() {
  local port=$(shuf -i 50000-65000 -n 1)
  ss -lat | grep $port > /dev/null
  if [[ $? == 1 ]] ; then
    echo $port
  else
    echo get::random::port
  fi
}

# Starts a local registry on the given port and returns the pid
function local::registry::start() {
  local registryPort registryPid localRegistry

  registryPort="$1"
  localRegistry="127.0.0.1:$registryPort"

  # Start a local in-memory registry so we can work with oci archives
  PORT=$registryPort crane registry serve --insecure > /dev/null 2>&1 &
  registryPid=$!

  # Stop the registry if execution is interrupted
  trap "kill $registryPid" 1 2 3 6

  # Wait for the registry to be available
  until crane catalog $localRegistry > /dev/null 2>&1; do
    sleep 1
  done

  echo $registryPid
}

main "${@:-}"
