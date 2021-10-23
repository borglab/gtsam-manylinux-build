# GTSAM Python Wheel Builder

![CI](https://github.com/ProfFan/gtsam-manylinux-build/workflows/CI/badge.svg) ![Pybind11 CI](https://github.com/borglab/gtsam-manylinux-build/workflows/Pybind11%20CI/badge.svg)

## How to Build on Linux

Run:
```bash
sudo docker run --rm -e PLAT=manylinux2014_x86_64 -v `pwd`:/io quay.io/pypa/manylinux2014_x86_64 /io/build-wheels.sh
```

You will need to rename the built files to a valid name:

```bash
mv gtsam-4.1.0-cp36-cp36m-manylinux2014_x86_64.none-manylinux2014_x86_64.whl gtsam-4.1.0-cp36-none-any.whl
```

## How to Build on macOS

Please consult `build-macos.h`.

# Current Build Date

2021-10-23

## Wheel Update Instructions

First, run `pip install twine`

```bash
twine upload --repository testpypi {WHEEL_FILE_NAME}.whl
```
For the main repo, the release version should have another number after it, e.g. `4.1.0-1`. For the [test pypi server](https://test.pypi.org/project/gtsam/), this is not necessary
enter username and password,  and the test version can be tested via:
```bash
pip install --index-url https://test.pypi.org/simple {PACKAGE_NAME}
```
