#!/usr/bin/env sh

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
		echo "-v $sccache_dir:/var/cache/sccache:Z -e SCCACHE_DIR=/var/cache/sccache"
	else
		echo "-e SCCACHE_BUCKET=$SCCACHE_BUCKET"
	fi
}

extra_args="$volume_mounts $(get_sccache_args)"

if [ "$HOST_MACHINE" = "Mac" ]; then
	docker run -it --rm -w "$1" $extra_args -v "$2" $4 "$3" $5
elif [ "$HOST_MACHINE" = "Linux" ]; then
	docker run -it --rm -u $(id -u):$(id -g) -w "$1" $extra_args -v "$2" $4 "$3" $5
fi
