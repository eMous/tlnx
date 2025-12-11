#!/bin/bash

# Docker-based test harness helpers

_docker_test_label="tlnx.testcontainer=true"
DOCKER_TEST_READY_IMAGE=""

docker_cli() {
	sudo docker "$@"
}

docker_test_should_run() {
	if [ "${TLNX_DOCKER_CHILD:-}" = "1" ]; then
		return 1
	fi
	if [ "${DOCKER_TEST_ENABLED:-false}" != "true" ]; then
		return 1
	fi
	return 0
}

docker_test_cleanup_old_containers() {
	local max_containers=${DOCKER_TEST_MAX_CONTAINERS:-5}
	if ! [[ "$max_containers" =~ ^[0-9]+$ ]] || [ "$max_containers" -le 0 ]; then
		return 0
	fi
	local -a existing_ids existing_names
	local line
	while IFS= read -r line; do
		[ -z "$line" ] && continue
		local cid name
		cid="${line%% *}"
		name="${line#* }"
		existing_ids+=("$cid")
		existing_names+=("$name")
	done < <(docker_cli ps -a --filter "label=${_docker_test_label}" --format '{{.ID}} {{.Names}}' --sort=created 2>/dev/null)

	local count=${#existing_ids[@]}
	while [ "$count" -ge "$max_containers" ]; do
		local idx=$((count - 1))
		local container_id="${existing_ids[$idx]}"
		local container_name="${existing_names[$idx]}"
		if [ -n "$container_id" ]; then
			log "INFO" "Removing old docker test container $container_name ($container_id) to enforce max $max_containers"
			if ! docker_cli rm -f "$container_id" >>"$LOG_FILE" 2>&1; then
				log "WARN" "Failed to remove container $container_name ($container_id)"
				break
			fi
		fi
		count=$((count - 1))
	done
}

docker_test_pull_image() {
	local image="${DOCKER_TEST_IMAGE:-ubuntu:24.04}"
	local build_context="${DOCKER_TEST_BUILD_CONTEXT:-}"
	local dockerfile="${DOCKER_TEST_DOCKERFILE:-Dockerfile}"
	if [ -n "$build_context" ] && [ -d "$build_context" ]; then
		local dockerfile_path="$build_context/$dockerfile"
		if [ -f "$dockerfile_path" ]; then
			log "INFO" "Building docker image $image using $dockerfile_path"
			if docker_cli build -t "$image" -f "$dockerfile_path" "$build_context" >>"$LOG_FILE" 2>&1; then
				DOCKER_TEST_READY_IMAGE="$image"
				return 0
			else
				log "WARN" "Docker build failed for $image; falling back to pull"
			fi
		else
			log "WARN" "Dockerfile $dockerfile_path not found; skipping build"
		fi
	fi

	if docker_cli image inspect "$image" >/dev/null 2>&1; then
		DOCKER_TEST_READY_IMAGE="$image"
		return 0
	fi

	log "INFO" "Pulling docker image $image for test harness"
	if docker_cli pull "$image" >>"$LOG_FILE" 2>&1; then
		DOCKER_TEST_READY_IMAGE="$image"
		return 0
	fi
	log "ERROR" "Failed to obtain docker image $image"
	return 1
}

run_docker_test() {
	if ! command -v docker >/dev/null 2>&1; then
		log "ERROR" "Docker CLI not found but DOCKER_TEST_ENABLED=true; install Docker or disable the test harness"
		return 1
	fi
	if ! docker_cli info >/dev/null 2>&1; then
		local daemon_started=false
		if command -v systemctl >/dev/null 2>&1; then
			log "WARN" "Docker daemon not reachable; attempting to start it via sudo systemctl start docker"
			if sudo systemctl start docker >>"$LOG_FILE" 2>&1; then
				if docker_cli info >/dev/null 2>&1; then
					log "INFO" "Docker daemon started successfully"
					daemon_started=true
				fi
			fi
		fi
		if [ "$daemon_started" = false ]; then
			log "ERROR" "Docker daemon not reachable; cannot start test harness"
			return 1
		fi
	fi

	docker_test_cleanup_old_containers

	DOCKER_TEST_READY_IMAGE=""
	if ! docker_test_pull_image; then
		return 1
	fi
	local image="$DOCKER_TEST_READY_IMAGE"
	log "INFO" "image using is $image ."
	local prefix="${DOCKER_TEST_CONTAINER_PREFIX:-tlnx-test}"
	local container_name="${prefix}-$(date +%Y%m%d%H%M%S)"

	local host_project_dir="$PROJECT_DIR"
	if command -v realpath >/dev/null 2>&1; then
		host_project_dir=$(realpath "$PROJECT_DIR")
	fi

	log "INFO" "Starting docker test container $container_name from $image"
	if ! docker_cli run -dit \
		--name "$container_name" \
		--hostname "$container_name" \
		--label "${_docker_test_label}" \
		--privileged \
		--cgroupns=host \
		--tmpfs /run \
		--tmpfs /run/lock \
		--tmpfs /tmp \
		--mount type=bind,src="$host_project_dir",target=/root/tlnx \
		--mount type=tmpfs,target=/root/tlnx/run \
		-v /sys/fs/cgroup:/sys/fs/cgroup:rw \
		"$image" >/dev/null; then
		log "ERROR" "Failed to start docker container $container_name"
		return 1
	fi

	log "INFO" "Docker container ready: $container_name"
	log "INFO" "Inspect it anytime via: sudo docker exec -it $container_name bash"

	local quoted_args=""
	if [ "$#" -gt 0 ]; then
		local arg
		for arg in "$@"; do
			quoted_args+=" $(printf '%q' "$arg")"
		done
	fi
	local exec_cmd="./tlnx${quoted_args}"
	log "INFO" "Executing: $exec_cmd inside $container_name"

	
	local -a exec_flags=(-e TLNX_FORCE_COLOR=1 -e TLNX_DOCKER_CHILD=1 -e TLNX_DOCKER_CONTAINER_NAME="$container_name" -w /root/tlnx -u root -it)
	if  command -v script >/dev/null 2>&1; then
		local docker_exec_cmd=""
		printf -v docker_exec_cmd '%q ' sudo docker exec "${exec_flags[@]}" "$container_name" bash -lc "$exec_cmd"
		log "INFO" "Non-tty environment detected; wrapping docker exec with script to force a pty"
		script -qefc "$docker_exec_cmd" /dev/null
	else
		log "INFO" "Non-tty environment detected; forcing docker exec -t anyway"
		docker_cli exec "${exec_flags[@]}" "$container_name" bash -lc "$exec_cmd"
	fi
	local status=$?
	if [ $status -ne 0 ]; then
		log "ERROR" "Docker test run inside $container_name failed with status $status"
	else
		log "INFO" "Docker test run inside $container_name finished successfully"
	fi
	return $status
}
