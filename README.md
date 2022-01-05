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

2022-01-04

We are building for the 4.2a1 release.

## Wheel Update Instructions

For all OSs and architectures we support:

First check if the wheels you have built can actually install and run by:

1. Create a clean virtual environment
2. `pip install {WHEEL}.whl` to install the wheel
3. run the GTSAM unit tests to make sure the wheel works by going to `gtsam_repo/python/gtsam/tests` and `python -m unittest discover`

* The most probable failures at this stage are:
  * The wheel repair (auditwheel/delocate) programs have bugs and produced wrong binaries.
  * Which needs manual patching, contact @ProfFan immediately

If you have confirmed that it works, you can then:

* Run `pip install twine` to install Twine
* After that, upload to Test PyPI by:
```bash
twine upload --repository testpypi {WHEEL_FILE_NAME}.whl
```
* Now, uninstall `gtsam` in the virtual env, do
```bash
pip install --index-url https://test.pypi.org/simple {PACKAGE_NAME}
```
and test again with the unit tests

* The most probable failures at this stage are:
  * Inconsistent version tags between the METADATA and the file name of the wheel
  * You did not test the wheel you uploaded in a fresh machine, so it's linking is not correct (only works for you)

* If that still works, you can try upload to REAL PyPI (THIS IS IRREVERSIBLE!!!)
```bash
twine upload {WHEEL_FILE_NAME}.whl
# OR if you tested all 8 wheels on Test PyPI and possible users
twine upload {directory containing all wheels}
```
* Finally test again by using normal `pip install gtsam`
* Rinse and repeat with every architecture that you are concerned with.
