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

CURRDIR=$(pwd)
BOOST_FOLDER=boost_${BOOST_VERSION//./_}

# Build Boost staticly
mkdir -p boost_build
cd boost_build
retry 3 wget https://boostorg.jfrog.io/artifactory/main/release/${BOOST_VERSION}/source/${BOOST_FOLDER}.tar.gz
tar -zxf ${BOOST_FOLDER}.tar.gz
cd ${BOOST_FOLDER}/

./bootstrap.sh --prefix=$CURRDIR/boost_install --with-libraries=serialization,filesystem,thread,system,atomic,date_time,timer,chrono,program_options,regex clang-darwin
./b2 -j$(sysctl -n hw.logicalcpu) cxxflags="-fPIC" runtime-link=static variant=release link=static install
