#!/usr/bin/env sh

set -x

_term() {
  docker kill $child
  status=$(docker inspect $child --format='{{.State.ExitCode}}')
  docker rm $child
  exit $status
}

trap _term SIGTERM
trap _term SIGINT

case "$(uname)" in
	Darwin*)	HOST_MACHINE=Mac;;
	*)		HOST_MACHINE=Linux;;
esac

volume_mounts=""

# Get the container's CARGO_HOME ENV, defaulting to /usr/local/cargo
cargo_home=$(docker inspect -f \
        '{{range $index, $value := .Config.Env}}{{println $value}}{{end}}' \
            "$3" | grep CARGO_HOME | cut -d"=" -f 2)
if [ -z "$cargo_home" ]; then
	cargo_home="/usr/local/cargo"
fi

[ ! -d "$CARGO_CACHE" ] && mkdir -p $CARGO_CACHE

volume_mounts="$volume_mounts -v $CARGO_CACHE:$cargo_home/registry:Z"

function get_sccache_args()
{
	if [ -z "$SCCACHE_BUCKET" ]; then
		local sccache_dir=""
		if [ -z "$sccache_dir" ]; then
			if [ "$HOST_MACHINE" = "Mac" ]; then
				sccache_dir=~/Library/Caches/Mozilla.sccache
			elif [ "$HOST_MACHINE" = "Linux" ]; then
				sccache_dir=~/.cache/sccache
			fi
		fi
		mkdir -p $sccache_dir
		echo "-v $sccache_dir:/var/cache/sccache:Z --env SCCACHE_DIR=/var/cache/sccache"
	else
		echo "--env SCCACHE_BUCKET=$SCCACHE_BUCKET --env SCCACHE_REGION=$SCCACHE_REGION --env SCCACHE_ERROR_LOG=/sccache.log --env SCCACHE_LOG=sccache=trace --env RUST_LOG=sccache=trace --env AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY --env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID"
	fi
}

extra_args="$volume_mounts $(get_sccache_args)"

trap _term SIGTERM
trap _term SIGINT

if [ "$HOST_MACHINE" = "Mac" ]; then
	child=$(docker run -d -w "$1" $extra_args -v "$2" $4 "$3" $5)
elif [ "$HOST_MACHINE" = "Linux" ]; then
	child=$(docker run -d -u $(id -u):$(id -g) -w "$1" $extra_args -v "$2" $4 "$3" $5)
fi

sleep 5

while docker exec "$child" sccache --show-stats
do
    sleep 1
done

# Tail the container til it's done
docker logs -f "$child"

docker cp $child:/sccache.log .
cat sccache.log

status=$(docker inspect $child --format='{{.State.ExitCode}}')
docker rm $child

exit $status
