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

# Install a system package required by our library
retry 3 yum install -y wget libicu libicu-devel

CURRDIR=$(pwd)

# Build Boost staticly
mkdir -p boost_build
cd boost_build
wget https://dl.bintray.com/boostorg/release/1.65.1/source/boost_1_65_1.tar.gz
tar xzf boost_1_65_1.tar.gz
cd boost_1_65_1
./bootstrap.sh --with-libraries=serialization,filesystem,thread,system,atomic,date_time,timer,chrono,program_options,regex
./b2 -j$(nproc) cxxflags="-fPIC" runtime-link=static variant=release link=static install

cd $CURRDIR

git clone https://github.com/borglab/gtsam.git -b develop

ORIGPATH=$PATH

PYTHON_LIBRARY=$(cd $(dirname $0); pwd)/libpython-not-needed-symbols-exported-by-interpreter
touch ${PYTHON_LIBRARY}

# FIX auditwheel
# https://github.com/pypa/auditwheel/issues/136
ls /opt/_internal
cd /opt/_internal/cpython-3.7.7/lib/python3.7/site-packages/auditwheel/
patch -p2 < /io/auditwheel.txt
cd $CURRDIR

mkdir -p /io/wheelhouse

declare -a PYTHON_VERS=( $1 )

# Compile wheels
for PYVER in ${PYTHON_VERS[@]}; do
    PYBIN="/opt/python/$PYVER/bin"
    "${PYBIN}/pip" install -r /io/requirements.txt
    PYTHONVER="$(basename $(dirname $PYBIN))"
    BUILDDIR="/io/gtsam_$PYTHONVER/gtsam_build"
    mkdir -p $BUILDDIR
    cd $BUILDDIR
    export PATH=$PYBIN:$ORIGPATH
    "${PYBIN}/pip" install cmake

    PYTHON_EXECUTABLE=${PYBIN}/python
    PYTHON_INCLUDE_DIR=$( find -L ${PYBIN}/../include/ -name Python.h -exec dirname {} \; )

    echo ""
    echo "PYTHON_EXECUTABLE:${PYTHON_EXECUTABLE}"
    echo "PYTHON_INCLUDE_DIR:${PYTHON_INCLUDE_DIR}"
    echo "PYTHON_LIBRARY:${PYTHON_LIBRARY}"
    
    cmake $CURRDIR/gtsam -DCMAKE_BUILD_TYPE=Release \
        -DGTSAM_BUILD_TESTS=OFF -DGTSAM_BUILD_UNSTABLE=ON \
        -DGTSAM_USE_QUATERNIONS=ON \
        -DGTSAM_BUILD_EXAMPLES_ALWAYS=OFF \
        -DGTSAM_INSTALL_CYTHON_TOOLBOX=ON \
        -DGTSAM_PYTHON_VERSION=Default \
        -DGTSAM_ALLOW_DEPRECATED_SINCE_V4=OFF \
        -DCMAKE_INSTALL_PREFIX=$BUILDDIR/../gtsam_install \
        -DBoost_USE_STATIC_LIBS=ON \
        -DBOOST_ROOT=/usr/local \
        -DBoost_NO_SYSTEM_PATHS=ON \
        -DBUILD_STATIC_METIS=ON \
        -DGTSAM_BUILD_WITH_MARCH_NATIVE=OFF \
        -DGTSAM_USE_CUSTOM_PYTHON_LIBRARY=ON \
        -DPYTHON_EXECUTABLE:FILEPATH=${PYTHON_EXECUTABLE} \
        -DPYTHON_INCLUDE_DIRS:PATH=${PYTHON_INCLUDE_DIR} \
        -DPYTHON_LIBRARY:FILEPATH=${PYTHON_LIBRARY}; ec=$?

    if [ $ec -ne 0 ]; then
        echo "Error:"
        cat ./CMakeCache.txt
        exit $ec
    fi
    set -e -x
    
    make -j$(nproc) install
    cd $BUILDDIR/../gtsam_install/cython
    
    # "${PYBIN}/pip" wheel . -w "/io/wheelhouse/"
    "${PYBIN}/python" setup.py bdist_wheel --python-tag=$PYTHONVER --plat-name=$PLAT
    cp ./dist/*.whl /io/wheelhouse
done

# Bundle external shared libraries into the wheels
for whl in /io/wheelhouse/*.whl; do
    auditwheel repair "$whl" -w /io/wheelhouse/
    rm $whl
done

for whl in /io/wheelhouse/*.whl; do
    new_filename=$(echo $whl | sed "s#\.none-$PLAT\.#.#g")
    new_filename=$(echo $new_filename | sed "s#\.$PLAT\.#.#g") # For 37 and 38
    new_filename=$(echo $new_filename | sed "s#-none-#-#g")
    mv $whl $new_filename
done

# Install packages and test
# for PYBIN in /opt/python/*/bin/; do
#     "${PYBIN}/pip" install python-manylinux-demo --no-index -f /io/wheelhouse
#     (cd "$HOME"; "${PYBIN}/nosetests" pymanylinuxdemo)
# done