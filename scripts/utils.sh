#! /bin/bash set -xv

source $HOME/scripts/fuzzers.sh

interactive_test(){
    echo "Select fuzzer"
    fuzzers=($(docker ps --filter name="fuzzer" --format '{{.Names}}' | sort))
    select fuzzer in "${fuzzers[@]}"; do
	if [[ -n "$fuzzer" ]]; then
            break
	else
            echo "Invalid selection, please try again."
	fi
    done
    test_all $fuzzer
}

test_all(){
    echo "Performing fuzz testing against all targets."
    for fuzzer in $(docker ps --filter name="${1:-fuzzer}" --format '{{.Names}}'); do
	echo "Current fuzzer: $fuzzer"
	for target in $(docker ps --format '{{.Names}}' | grep "target"); do
	    echo "Current target: $target"
	    port=$(docker ps --filter name="$target" --format '{{.Label "port"}}')
	    test_with_fuzzer $fuzzer $target $port
	done
	rebuild_targets $fuzzer
    done
    rm -rf $CODE_COVERAGE_PATH/target-*
    notify "Fuzz test against all targets has finished"
}

print_fuzzers(){
    echo -ne "\nFuzzer-services are running:"
    echo -e "\033[0;31m"
    docker ps --filter name="fuzzer" --format '{{.Names}}'
    echo -en "\033[0m"
}

print_targets(){
    echo -ne "\nTarget services are running:"
    echo -e "\033[0;31m"
    docker ps --filter name="target" --format '{{.Names}} @ {{.Label "port"}}'
    echo -en "\033[0m"
}

print_schemas(){
    echo -e "\nAvailable API schemas:"
    echo -en "\033[0;31m"
    ls -1 ./schemas
    echo -e "\033[0m"
}

print_all(){
    print_targets
    print_fuzzers
    print_schemas
}

output_archival(){
    tar -cf output.tar.gz $HOME/outputs/
}

dumb_server_outputs(){
    for item in $(docker ps --filter name="target" --format '{{.Names}}'); do
	echo -e "\nGenerating code coverage report for $item"
	docker exec $item /bin/sh -c /output.sh
    done
}

print_help(){
    echo -e "\nCommon workflow to test all targets with all fuzzers:\n" \
	 "\t1. Build the environment with `be`\n" \
	 "\t2. Choose a fuzzer\n" \
	 "\t3. With the chosen fuzzer test all targets as per insturctions (see docs)\n" \
	 "\t4. Run `og` to get code coverage dumps\n" \
	 "\t5. Run `oa` to create output.tar.gz archival of all outputs\n" \
	 "\t6. Repeat the process with next fuzzer until all fuzzers have been used"
    
    echo -e "\nAvailable commands:\n" \
	 "\t pa | print_all : prints all info you need regarding services\n" \
	 "\t pf | print_fuzzers : prints all available fuzzers\n" \
	 "\t ps | print_schemas : prints all availabale schemas\n" \
	 "\t pt | print_targets : prints all available targets\n" \
	 "\t og | outut_generation: make all (Java) target containers dump code coverage to \$HOME/outputs\n" \
	 "\t oa | output_archival: creates archive of all outputs to \$HOME/output.tar.gz\n" \
	 "\t be | build_environment: same as running \$HOME/build_environment.sh\n"
}

ensure_correct_path() {
    local expected_dir="${1:-docker}"

    if [ ! -d "./$expected_dir" ]; then
        echo "Error: Expected to run this script from a directory" \
	     "containing the '$expected_dir' folder."
        return 1
    fi
    return 0
}

read_env() {
    if [ ! -f $HOME/.env ]; then
        echo "Error: .env file not found in the current directory."
        return 1
    fi

    set -a
    source $HOME/.env
    set +a

    if [ -z "$API_REPO_URL" ]; then
        echo "Error: Please set 'API_REPO_URL' in the .env file."
        return 1
    fi

    if [ -z "$FORK_OWNER" ]; then
        echo "Error: Please set 'FORK_OWNER' in the .env file."
        return 1
    fi

    echo "export API_REPO_URL=\"$API_REPO_URL\"" >> /tmp/env_cache_file.env
    echo "export FORK_OWNER=\"$FORK_OWNER\"" >> /tmp/env_cache_file.env

    return 0
}

read_notification_service() {
    echo "export NOTIFICATION_SERVICE=\"$NOTIFICATION_SERVICE\"" >> /tmp/env_cache_file.env
}


read_target_branch() {
    if [ -z "${TARGET_BRANCH+x}" ]; then
        export TARGET_BRANCH="master"
    fi

    read -rp "Branch for target service (leave empty for: ${TARGET_BRANCH}): " target

    if [ -n "$target" ]; then
        export TARGET_BRANCH="$target"
    fi

    echo "export TARGET_BRANCH=\"$TARGET_BRANCH\"" >> /tmp/env_cache_file.env
}

read_api_branch(){
    if [ -z "${API_BRANCH+x}" ]; then
	export API_BRANCH="main"
    fi

    read -rp "Branch for API (leave empty for: ${API_BRANCH}): " api

    if [ -n "$api" ]; then
	export API_BRANCH="$api"
    fi
    echo "export API_BRANCH=\"$API_BRANCH\"" >> /tmp/env_cache_file.env
}

construct_and_set_env_vars(){
    # TODO move static ones to .env
    export LOG_TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
    export LOG_ID="${LOG_TIMESTAMP}_target-${TARGET_BRANCH}_api-${API_BRANCH}"
    export HOST_OUTPUTS="${HOME}/outputs/${LOG_ID}"

    export CODE_COVERAGE_PATH="${HOST_OUTPUTS}/targets/codecoverage"
    export FUZZER_REPORT_PATH="${HOST_OUTPUTS}/fuzzers/"
    export CONTAINER_OUTPUTS="/output"
    export FUZZER_SCHEMA_DIR="/schemas"
    export HOST_SCHEMA_DIR="${HOME}/schemas"
    export FUZZER_DEFAULT_ENTRYPOINT="tail -f /dev/null"

    echo "export LOG_TIMESTAMP=\"$LOG_TIMESTAMP\"" >> /tmp/env_cache_file.env
    echo "export LOG_ID=\"$LOG_ID\"" >> /tmp/env_cache_file.env
    echo "export CODE_COVERAGE_PATH=\"$CODE_COVERAGE_PATH\"" >> /tmp/env_cache_file.env
    echo "export FUZZER_REPORT_PATH=\"$FUZZER_REPORT_PATH\"" >> /tmp/env_cache_file.env
    echo "export HOST_OUTPUTS=\"$HOST_OUTPUTS\"" >> /tmp/env_cache_file.env
    echo "export CONTAINER_OUTPUTS=\"$CONTAINER_OUTPUTS\"" >> /tmp/env_cache_file.env
    echo "export FUZZER_SCHEMA_DIR=\"$FUZZER_SCHEMA_DIR\"" >> /tmp/env_cache_file.env
    echo "export HOST_SCHEMA_DIR=\"$HOST_SCHEMA_DIR\"" >> /tmp/env_cache_file.env
    echo "export FUZZER_DEFAULT_ENTRYPOINT=\"$FUZZER_DEFAULT_ENTRYPOINT\"" >> /tmp/env_cache_file.env

}

fetch_and_link_api_spec() {
    echo -e "\nPreparing API specifications.."
    local tmp_repo_location="/tmp/${LOG_TIMESTAMP}_${API_BRANCH}"

    if [ -z "$API_REPO_URL" ] || [ -z "$API_BRANCH" ]; then
        echo "Error: API_REPO_URL and API_BRANCH must be set" \
	     "before calling this function."
        return 1
    fi

    if ! git clone "$API_REPO_URL" "$tmp_repo_location" -q; then
        echo "Error: Failed to clone $API_REPO_URL"
        return 1
    fi

    pushd "$tmp_repo_location" > /dev/null || return 1

    if ! git checkout "$API_BRANCH" -q 2>/dev/null; then
        echo "Error: Failed to checkout branch \"$API_BRANCH\"."
        echo -e "\nAvailable branches:"
        git branch -a --format='%(refname:short)'
        popd > /dev/null
        return 1
    fi

    popd > /dev/null

    ln -sfn "$tmp_repo_location" ./schemas
    echo "API specifications are ready."
}

build_and_start_containers() {
    echo -e "\nBuilding new target services..." \
	 "Fuzzing is slow anyways, right? :-)"

    local docker_dir="${HOME}/docker"

    if [ ! -d "$docker_dir" ]; then
        echo "Error: '$docker_dir' directory not found."
        return 1
    fi

    pushd "$docker_dir" > /dev/null || return 1

    docker compose build --quiet && \
	docker compose --progress=quiet up --detach

    popd > /dev/null
    notify "Containers have been built"
}

prune_docker(){
    echo -e "\nCleaning up old images and containers..."
    docker stop $(docker ps -a -q) 2> /dev/null
    docker system prune -fa > /dev/null
}

flush_cache(){
    rm /tmp/env_cache_file.env
}


setup_environment(){
    flush_cache
    ensure_correct_path
    read_env
    read_target_branch
    read_api_branch
    construct_and_set_env_vars
    prune_docker

    echo -e "\n\nStarting to prepare the environment."
    echo -e "This may take a couple of minutes to ensure clean testing environment."
    fetch_and_link_api_spec
    build_and_start_containers
    print_all
}

rebuild_targets(){
    source /tmp/env_cache_file.env

    local docker_dir="${HOME}/docker"
    local seconds_to_wait=60
    
    if [ ! -d "$docker_dir" ]; then
        echo "Error: '$docker_dir' directory not found."
        return 1
    fi

    pushd "$docker_dir" > /dev/null || return 1

    dumb_server_outputs

    mkdir -p "$CODE_COVERAGE_PATH/$1"

    find "$CODE_COVERAGE_PATH" -mindepth 1 -maxdepth 1 -type d -name "target-*" | while read dir; do
	mkdir -p "$CODE_COVERAGE_PATH/$1/$(basename "$dir")"
	rsync -a --remove-source-files "$dir/" "$CODE_COVERAGE_PATH/$1/$(basename "$dir")/"
	rm -rf "$dir"/*   # leave empty dir for container mounts
    done


    echo "Databases are always built due to difficult nature of figuring out container dependencies"
    for target in $(docker container ls -a --format '{{.Names}}'); do
	echo "Recreating $target"
	docker compose --progress=quiet up -d --force-recreate --remove-orphans $target
    done    

    popd > /dev/null
    echo "Services were built. " \
	 "Sleeping for a $seconds_to_wait seconds since some of the databases are slow to start and this is a quick fix to it. "\
	 "Feel free to implement a health check, it could save some time."
    sleep $seconds_to_wait
}

test_with_fuzzer(){
    # $1 = fuzzer
    # $2 = target
    # $3 = target port
    local seconds=20
    echo "Rebuilding $1 to ensure clean test"
    docker compose \
	   --progress=quiet \
	   up \
	   --detach \
	   --force-recreate \
	   --remove-orphans \
	   $1
    echo "Successfully rebuilt $1. Waiting $seconds seconds to ensure it's up and running"
    echo "Feel free to create health check to cut down the wait time"
    sleep $seconds
    echo "Starting to fuzz"
    test_with_$1 $2 $3
}

rebuild_fuzzers(){
    source /tmp/env_cache_file.env

    local docker_dir="${HOME}/docker"

    if [ ! -d "$docker_dir" ]; then
        echo "Error: '$docker_dir' directory not found."
        return 1
    fi

    pushd "$docker_dir" > /dev/null || return 1

    for fuzzer in $(docker container ls -a --filter name="fuzzer" --format '{{.Names}}'); do
	echo "Recreating $fuzzer"
	docker compose --progress=quiet up -d --force-recreate --remove-orphans $target 
    done    

    popd > /dev/null
}

notify(){
    if [ -n "${NOTIFICATION_SERVICE+x}" ]; then
	curl -d "$1" "$NOTIFICATION_SERVICE"
    fi

}
