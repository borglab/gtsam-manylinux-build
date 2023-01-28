#!/bin/bash

CURRDIR=$(pwd)

# Clone GTSAM
GTSAM_BRANCH="release/4.2.0"
git clone https://github.com/borglab/gtsam.git -b $GTSAM_BRANCH /gtsam

# Set the build directory
BUILDDIR="/io/gtsam_build"
mkdir $BUILDDIR
cd $BUILDDIR

PYBIN="/opt/python/$PYTHON_VERSION/bin"
PYVER_NUM_FULL=$($PYBIN/python -c "import sys;print(sys.version.split(\" \")[0])")
PYVER_NUM=${PYVER_NUM_FULL%.*}
PYTHONVER="$(basename $(dirname $PYBIN))"

export PATH=$PYBIN:$PATH

${PYBIN}/pip install -r /io/requirements.txt

PYTHON_EXECUTABLE=${PYBIN}/python
# We use distutils to get the include directory and the library path directly from the selected interpreter
# We provide these variables to CMake to hint what Python development files we wish to use in the build.
PYTHON_INCLUDE_DIR=$(${PYTHON_EXECUTABLE} -c "from sysconfig import get_paths as gp; print(gp()['include'])")
PYTHON_LIBRARY=$(${PYTHON_EXECUTABLE} -c "import sysconfig; print(sysconfig.get_config_var('LIBDIR'))")

echo ""
echo "PYBIN:${PYBIN}"
echo "PYVER_NUM:${PYVER_NUM}"
echo "PYTHON_EXECUTABLE:${PYTHON_EXECUTABLE}"
echo "PYTHON_INCLUDE_DIR:${PYTHON_INCLUDE_DIR}"
echo "PYTHON_LIBRARY:${PYTHON_LIBRARY}"
echo ""

cmake /gtsam -DCMAKE_BUILD_TYPE=Release \
    -DGTSAM_BUILD_TESTS=OFF -DGTSAM_BUILD_UNSTABLE=ON \
    -DGTSAM_USE_QUATERNIONS=OFF \
    -DGTSAM_BUILD_EXAMPLES_ALWAYS=OFF \
    -DGTSAM_ALLOW_DEPRECATED_SINCE_V42=OFF \
    -DCMAKE_INSTALL_PREFIX=$BUILDDIR/../gtsam_install \
    -DBoost_USE_STATIC_LIBS=ON \
    -DBOOST_ROOT=/usr/local \
    -DBoost_NO_SYSTEM_PATHS=ON \
    -DBUILD_STATIC_METIS=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DGTSAM_BUILD_WITH_MARCH_NATIVE=OFF \
    -DGTSAM_WITH_TBB=OFF \
    -DGTSAM_BUILD_PYTHON=ON \
    -DGTSAM_PYTHON_VERSION=$PYVER_NUM;
    # -DPYTHON_LIBRARY=$PYTHON_LIBRARY \
    # -DPYTHON_INCLUDE_DIR=$PYTHON_INCLUDE_DIR;
ec=$?

if [ $ec -ne 0 ]; then
    echo "Error:"
    cat ./CMakeCache.txt
    exit $ec
fi
set -e -x

make -j$(nproc) install

mkdir -p /io/wheelhouse

cd python

"${PYBIN}/python" setup.py bdist_wheel --python-tag=$PYTHONVER --plat-name=$PLAT

cp ./dist/*.whl /io/wheelhouse/

# Bundle external shared libraries into the wheels
for whl in ./dist/*.whl; do
    auditwheel repair "$whl" -w /io/wheelhouse/
done

for whl in /io/wheelhouse/*.whl; do
    new_filename=$(echo $whl | sed "s#\.none-manylinux2014_x86_64\.#.#g")
    new_filename=$(echo $new_filename | sed "s#\.manylinux2014_x86_64\.#.#g") # For 37 and 38
    new_filename=$(echo $new_filename | sed "s#-none-#-#g")
    mv $whl $new_filename
done
