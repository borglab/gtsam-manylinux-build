# GTSAM Python Wheel Builder

![CI](https://github.com/ProfFan/gtsam-manylinux-build/workflows/CI/badge.svg) ![Pybind11 CI](https://github.com/borglab/gtsam-manylinux-build/workflows/Pybind11%20CI/badge.svg)

## How to Build

```bash
sudo docker run --rm -e PLAT=manylinux2014_x86_64 -v `pwd`:/io quay.io/pypa/manylinux2014_x86_64 /io/build-wheels.sh
```

You will need to rename the built files to a valid name:

```bash
mv gtsam-4.0.2-cp36-cp36m-manylinux2014_x86_64.none-manylinux2014_x86_64.whl gtsam-4.0.2-cp36-none-any.whl
```