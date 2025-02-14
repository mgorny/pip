#!/usr/bin/env bash

PYTHON=python3.13

die() {
	echo "${BASH_SOURCE[1]}:${BASH_LINENO[0]} (in ${FUNCNAME[1]}) failed" >&2
	exit 1
}

run_pip() {
	# this subshell is used to redirect time output
	(
		uv venv -p "${PYTHON}" "${tmpdir}/venv" &> "${tmpdir}/log" &&
		time -p "${tmpdir}/venv/bin/python" -m pip install "${package}" &> "${tmpdir}"/log &&
		rm -rf "${tmpdir}/venv" &> "${tmpdir}/log"
	) 2>&1

	if [[ ${?} -ne 0 ]]; then
		cat "${tmpdir}"/log >&2
		die
	fi
}

main() {
	local packages=( pytest aiohttp poetry spyder )
	local multipliers=( 1 10 25 50 75 150 300 500 1000 )

	# assuming /tmp is likely to be tmpfs, this should speed things up
	local -x tmpdir=$(mktemp -d || die)
	trap "rm -rf ${tmpdir}" EXIT

	local -x LC_ALL=C
	local -x PYTHONPATH=src
	local -x XDG_CACHE_HOME=${tmpdir}/cache

	local package run res
	local -x TAGS_MULTIPLIER=1
	for package in "${packages[@]}"; do
		# warmup / prefetch
		echo "Benchmarking ${package} ..." >&2
		run_pip >/dev/null

		for TAGS_MULTIPLIER in "${multipliers[@]}"; do
			local tags=$("${PYTHON}" <<<'import pip._internal.utils.compatibility_tags as ct; print(len(ct.get_supported()))' || die)
			res=()
			for run in {1..10}; do
				res+=( "$(run_pip | sed -n -e 's:real ::p')" )
			done
			echo "${package} ${tags} ${res[*]}"
		done
	done
}

main
