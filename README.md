# GTSAM Python Wheel Builder

## How to Build

```bash
sudo docker run --rm -e PLAT=manylinux2014_x86_64 -v `pwd`:/io quay.io/pypa/manylinux2014_x86_64 /io/build-wheels.sh
```

You will need to rename the built files to a valid name:

```bash
mv gtsam-4.0.2-cp36-cp36m-manylinux2014_x86_64.none-manylinux2014_x86_64.whl gtsam-4.0.2-cp36-none-any.whl
```