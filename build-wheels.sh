#!/bin/bash
set -e -x

# Install a system package required by our library
yum install -y boost-devel

CURRDIR=$(pwd)

git clone https://github.com/borglab/gtsam.git

ORIGPATH=$PATH

# Compile wheels
for PYBIN in /opt/python/*/bin; do
    "${PYBIN}/pip" install -r /io/requirements.txt
    PYTHONVER="$(basename $(dirname $PYBIN))"
    BUILDDIR="/io/gtsam_$PYTHONVER/gtsam_build"
    mkdir -p $BUILDDIR
    cd $BUILDDIR
    export PATH=$PYBIN:$ORIGPATH
    "${PYBIN}/pip" install cmake
    cmake $CURRDIR/gtsam -DCMAKE_BUILD_TYPE=RelWithDebInfo -DGTSAM_BUILD_TESTS=OFF -DGTSAM_BUILD_UNSTABLE=ON -DGTSAM_USE_QUATERNIONS=OFF -DGTSAM_BUILD_EXAMPLES_ALWAYS=OFF -DGTSAM_INSTALL_CYTHON_TOOLBOX=ON -DGTSAM_PYTHON_VERSION=3 -DGTSAM_ALLOW_DEPRECATED_SINCE_V4=OFF -DCMAKE_INSTALL_PREFIX=$BUILDDIR/../gtsam_install
    make -j3 install
    cd $BUILDDIR/../gtsam_install/cythonRelWithDebInfo
    
    "${PYBIN}/pip" wheel /io/ -w wheelhouse/
done

# Bundle external shared libraries into the wheels
for whl in wheelhouse/*.whl; do
    auditwheel repair "$whl" --plat $PLAT -w /io/wheelhouse/
done

# Install packages and test
for PYBIN in /opt/python/*/bin/; do
    "${PYBIN}/pip" install python-manylinux-demo --no-index -f /io/wheelhouse
    (cd "$HOME"; "${PYBIN}/nosetests" pymanylinuxdemo)
done