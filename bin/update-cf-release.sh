#!/bin/sh

set -e

GIT_ROOT=${GIT_ROOT:-$(git rev-parse --show-toplevel)}

RELEASE=${1}

VERSION_INFO=$("${GIT_ROOT}/bin/get-cf-versions.sh" "${RELEASE}")

CF_RELEASE=$(echo "${VERSION_INFO}" | jq -r .[\"cf-release-commit-sha\"])
ETCD_RELEASE=v$(echo "${VERSION_INFO}" | jq -r .[\"etcd-release-version\"])
DIEGO_RELEASE=v$(echo "${VERSION_INFO}" | jq -r .[\"diego-release-version\"])
CFLINUXFS2_ROOTFS_RELEASE=v$(echo "${VERSION_INFO}" | jq -r .[\"cflinuxfs2-rootfs-release-version\"])
GARDEN_RUNC_RELEASE=v$(echo "${VERSION_INFO}" | jq -r .[\"garden-runc-release-version\"])

update_submodule () {
	release_name=${1}
	commit_id=${2}
	cd "${GIT_ROOT}/src/${release_name}"
	git fetch --all
	cd "${GIT_ROOT}"
	git clone "src/${release_name}" "src/${release_name}-clone" --recursive
	cd "src/${release_name}-clone"
	git fetch --all
	git checkout "${commit_id}"
	git submodule update --init --recursive
}

for release_name in cf-release diego-release etcd-release garden-runc-release
do
	clone_dir=${GIT_ROOT}/src/${release_name}-clone
	if test -e "${clone_dir}"
	then
		echo "${clone_dir} already exists from previous upgrade."
		exit 1
	fi
done

update_submodule cf-release "${CF_RELEASE}"
update_submodule diego-release "${DIEGO_RELEASE}"
update_submodule etcd-release "${ETCD_RELEASE}"
update_submodule cflinuxfs2-rootfs-release "${CFLINUXFS2_ROOTFS_RELEASE}"
update_submodule garden-runc-release "${GARDEN_RUNC_RELEASE}"
