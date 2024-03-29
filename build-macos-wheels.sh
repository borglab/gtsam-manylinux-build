#!/bin/bash
set -x -e

function retry {
  local retries=$1
  shift

  local count=0
  until "$@"; do
    exit=$?
    wait=$((2 ** $count))
    count=$(($count + 1))
    if [ $count -lt $retries ]; then
      echo "Retry $count/$retries exited $exit, retrying in $wait seconds..."
      sleep $wait
    else
      echo "Retry $count/$retries exited $exit, no more retries left."
      return $exit
    fi
  done
  return 0
}

brew update
brew install wget "$1" cmake || true

CURRDIR=$(pwd)
GTSAM_LIB_VERSION="4.2"
GTSAM_PYTHON_VERSION="4.2"

cd $CURRDIR
mkdir -p $CURRDIR/wheelhouse_unrepaired
mkdir -p $CURRDIR/wheelhouse

git clone https://github.com/borglab/gtsam.git --depth 1 -b $GTSAM_RELEASE_TAG

cd $CURRDIR/gtsam

patch -p0 < ../setup.py.in.patch

cd $CURRDIR

ORIGPATH=$PATH

PYTHON_LIBRARY=$(cd $(dirname $0); pwd)/libpython-not-needed-symbols-exported-by-interpreter
touch ${PYTHON_LIBRARY}

declare -a PYTHON_VERS=( $1 )

# Get the python version numbers only by splitting the string
split_array=(${PYTHON_VERS//@/ })
VERSION_NUMBER=${split_array[1]}

# Compile wheels
for PYVER in ${PYTHON_VERS[@]}; do
    PYBIN="$(brew --prefix "$1")/bin"
    PIP="${PYBIN}/pip${VERSION_NUMBER}"
    ${PIP} install -r ./requirements.txt

    PYTHONVER="$(basename $(dirname $PYBIN))"
    BUILDDIR="$CURRDIR/gtsam_$PYTHONVER/gtsam_build"
    mkdir -p $BUILDDIR
    cd $BUILDDIR
    export PATH=$PYBIN:$PYBIN:$(brew --prefix)/bin:$ORIGPATH
    ${PIP} install delocate

    PYTHON_EXECUTABLE=${PYBIN}/python${VERSION_NUMBER}

    # echo ""
    # echo "PYTHON_EXECUTABLE:${PYTHON_EXECUTABLE}"
    # echo "PYTHON_INCLUDE_DIR:${PYTHON_INCLUDE_DIR}"
    # echo "PYTHON_LIBRARY:${PYTHON_LIBRARY}"
    
    cmake $CURRDIR/gtsam -DCMAKE_BUILD_TYPE=Release \
        -DGTSAM_BUILD_TESTS=OFF -DGTSAM_BUILD_UNSTABLE=ON \
        -DGTSAM_USE_QUATERNIONS=OFF \
        -DGTSAM_BUILD_EXAMPLES_ALWAYS=OFF \
        -DGTSAM_PYTHON_VERSION=$VERSION_NUMBER \
        -DGTSAM_BUILD_WITH_MARCH_NATIVE=OFF \
        -DGTSAM_ALLOW_DEPRECATED_SINCE_V42=OFF \
        -DCMAKE_INSTALL_PREFIX="$BUILDDIR/../gtsam_install" \
        -DBoost_USE_STATIC_LIBS=ON \
        -DBoost_USE_STATIC_RUNTIME=ON \
        -DBOOST_ROOT=$CURRDIR/boost_install \
        -DCMAKE_PREFIX_PATH=$CURRDIR/boost_install/lib/cmake/Boost-1.73.0/ \
        -DBoost_NO_SYSTEM_PATHS=OFF \
        -DBUILD_STATIC_METIS=ON \
        -DGTSAM_BUILD_PYTHON=ON \
        -DPYTHON_EXECUTABLE=${PYTHON_EXECUTABLE};
    ec=$?

    if [ $ec -ne 0 ]; then
        echo "Error:"
        cat ./CMakeCache.txt
        exit $ec
    fi
    set -e -x
    
    make -j$(sysctl -n hw.logicalcpu) install
    
    # "${PYBIN}/pip" wheel . -w "/io/wheelhouse/"
    cd python

    ${PYTHON_EXECUTABLE} setup.py bdist_wheel
    cp ./dist/*.whl $CURRDIR/wheelhouse_unrepaired
done

# Bundle external shared libraries into the wheels
for whl in $CURRDIR/wheelhouse_unrepaired/*.whl; do
    delocate-listdeps --all "$whl"
    delocate-wheel -w "$CURRDIR/wheelhouse" -v "$whl"
    rm $whl
done

cd $CURRDIR/wheelhouse

# Only for 3.8

# if [ "$VERSION_NUMBER" != "3.8" ]; then
exit 0
# fi

for whln in $CURRDIR/wheelhouse/*.whl; do
    whl=$(basename "${whln}" .whl)
    unzip $whl.whl -d $whl

    cd $whl
    install_name_tool -change @loader_path/../../../gtsam.dylibs/libgtsam.$GTSAM_LIB_VERSION.dylib @loader_path/../gtsam.dylibs/libgtsam.$GTSAM_LIB_VERSION.dylib gtsam-$GTSAM_PYTHON_VERSION.data/purelib/gtsam/gtsam.cpython-*-darwin.so

    install_name_tool -change @loader_path/../../../gtsam.dylibs/libgtsam.$GTSAM_LIB_VERSION.dylib @loader_path/../gtsam.dylibs/libgtsam.$GTSAM_LIB_VERSION.dylib gtsam-$GTSAM_PYTHON_VERSION.data/purelib/gtsam_unstable/gtsam_unstable.cpython-*-darwin.so

    install_name_tool -change @loader_path/../../../gtsam.dylibs/libgtsam_unstable.$GTSAM_LIB_VERSION.dylib @loader_path/../gtsam.dylibs/libgtsam_unstable.$GTSAM_LIB_VERSION.dylib gtsam-$GTSAM_PYTHON_VERSION.data/purelib/gtsam_unstable/gtsam_unstable.cpython-*-darwin.so

    zip -r ../$whl.whl ./*

    cd $CURRDIR/wheelhouse
    rm -rf $whl
done
