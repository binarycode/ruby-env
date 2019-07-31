#!/usr/bin/env bash

set -e

RUBY_INSTALL_VERSION="0.7.0"

DEBIAN_VERSION="buster"

while true
do
  case "$1" in
    -r | --ruby )
      shift
      RUBY_VERSION=$1
      shift
      ;;

    -d | --debian )
      shift
      DEBIAN_VERSION=$1
      shift
      ;;


    -h | --help )
      echo "Usage: build.sh -r RUBY_VERSION [-d DEBIAN_VERSION]"
      echo
      echo " -r, --ruby"
      echo "   ruby version"
      echo
      echo " -d, --debian"
      echo "   debian version (buster by default)"
      echo
      exit 0
      ;;

    -- )
      shift
      break
      ;;

    * )
      break
      ;;
  esac
done

if [ -z "$RUBY_VERSION" ]
then
  echo "RUBY_VERSION is empty"
  exit 1
fi

if [ -z "$DEBIAN_VERSION" ]
then
  echo "DEBIAN_VERSION is empty"
  exit 1
fi

PARENT_IMAGE="debian:$DEBIAN_VERSION"

TAG="ruby-$RUBY_VERSION:$DEBIAN_VERSION"

cleanup() {
  if [ "$build_mount" != "" ]; then buildah unmount $build_container; fi
  if [ "$mount" != "" ]; then buildah unmount $container; fi
  if [ "$build_container" != "" ]; then buildah rm $build_container; fi
  if [ "$container" != "" ]; then buildah rm $container; fi
}

trap cleanup EXIT INT TERM

build_container=$(buildah from $PARENT_IMAGE)

# dependencies
buildah run $build_container sh -c '
DEBIAN_FRONTEND=noninteractive apt-get -qq update
DEBIAN_FRONTEND=noninteractive apt-get -qq install -y --no-install-recommends \
  build-essential \
  ca-certificates \
  wget
'

# ruby-install
buildah run $build_container sh -c "
cd /tmp
wget -O ruby-install-$RUBY_INSTALL_VERSION.tar.gz https://github.com/postmodern/ruby-install/archive/v$RUBY_INSTALL_VERSION.tar.gz
tar -xzvf ruby-install-$RUBY_INSTALL_VERSION.tar.gz
"

# prevent documentation generation for gems
buildah run $build_container sh -c "
echo 'gem: --no-document' > ~/.gemrc
"

# ruby
buildah run $build_container sh -c "
/tmp/ruby-install-$RUBY_INSTALL_VERSION/bin/ruby-install --system ruby $RUBY_VERSION -- --disable-install-doc
"

# cleanup
buildah run $build_container sh -c "
rm -rf /usr/local/src
"

container=$(buildah from $PARENT_IMAGE)

build_mount=$(buildah mount $build_container)
mount=$(buildah mount $container)

cp -r $build_mount/etc/* $mount/etc/
cp -r $build_mount/lib/* $mount/lib/
cp -r $build_mount/usr/* $mount/usr/

buildah commit $container $TAG
