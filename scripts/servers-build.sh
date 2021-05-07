#!/bin/bash

set -e -x -E


echo "WORKSPACE=$WORKSPACE"

# Verify that version references are up to date.
$WORKSPACE/integration/extra/release_tool.py --verify-integration-references

build_servers_repositories() {
    # Use release tool to query for available docker names.
    for docker in $($WORKSPACE/integration/extra/release_tool.py --list docker ); do (

        git=$($WORKSPACE/integration/extra/release_tool.py --map-name docker $docker git)
        docker_url=$($WORKSPACE/integration/extra/release_tool.py --map-name docker $docker docker_url)

        case "$docker" in
            deployments|deployments-enterprise|deviceauth|inventory|inventory-enterprise|tenantadm|useradm|useradm-enterprise|workflows|workflows-enterprise|create-artifact-worker|auditlogs|mtls-ambassador|deviceconnect|deviceconfig|devicemonitor)
                cd go/src/github.com/mendersoftware/$git
                docker build -t $docker_url:pr .
                $WORKSPACE/integration/extra/release_tool.py --set-version-of $docker --version pr
                ;;

            workflows-worker|workflows-enterprise-worker)
                cd go/src/github.com/mendersoftware/$git
                docker build -t $docker_url:pr -f Dockerfile.worker .
                $WORKSPACE/integration/extra/release_tool.py --set-version-of $docker --version pr
                ;;

            gui)
                cd gui
                # GIT_REF + GIT_COMMIT for 2.3 or older, GIT_COMMIT_TAG for newer
                docker build \
                    -t $docker_url:pr \
                    --build-arg GIT_REF=$(git describe) \
                    --build-arg GIT_COMMIT=$(git rev-parse --short HEAD) \
                    --build-arg GIT_COMMIT_TAG="$(git describe)" \
                    .
                $WORKSPACE/integration/extra/release_tool.py --set-version-of $docker --version pr
                ;;

            mender-client-docker*)
                # Built directly on an independent pipeline job
                :
                ;;

            mender-client-qemu*)
                # Built in yocto-build-and-test.sh::build_and_test_client
                :
                ;;

            api-gateway)
                cd $git
                docker build -t $docker_url:pr .
                $WORKSPACE/integration/extra/release_tool.py --set-version-of $docker --version pr
                ;;

            mender-conductor|mender-conductor-enterprise)
                cd go/src/github.com/mendersoftware/$git
                docker build --build-arg REVISION=pr -t $docker_url:pr ./server
                $WORKSPACE/integration/extra/release_tool.py --set-version-of $docker --version pr
                ;;

            email-sender)
                cd go/src/github.com/mendersoftware/$git
                docker build -t $docker_url:pr ./workers/send_email
                $WORKSPACE/integration/extra/release_tool.py --set-version-of $docker --version pr
                ;;

            org-welcome-email-preparer)
                cd go/src/github.com/mendersoftware/$git
                docker build --build-arg REVISION=pr -t $docker_url:pr ./workers/prepare_org_welcome_email
                $WORKSPACE/integration/extra/release_tool.py --set-version-of $docker --version pr
                ;;

            *)
                echo "Don't know how to build docker image $docker"
                exit 1
                ;;
        esac
    ); done
}

build_servers_repositories
