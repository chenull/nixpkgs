{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  luajit,
  openssl,
  libaio,
  libcap,
  libxcrypt,
  pcre,
  breakpointHook,
}:

stdenv.mkDerivation rec {
  pname = "openlitespeed";
  version = "1.8.4";

  # src = fetchFromGitHub {
  #   owner = "litespeedtech";
  #   repo = "openlitespeed";
  #   fetchSubmodules = true;
  #   # tag = "v${version}";
  #   rev = "7743be878790450d529f52f3a9f6ff4cc78cb01c";
  #   hash = "sha256-n79dZYWlcKHVUg6wxAxllFSGwaBLElA51NCbRzSb+00=";
  # };
  src = /home/chenull/Repo/litespeedtech/openlitespeed;

  bcryptSrc = fetchFromGitHub {
    owner = "litespeedtech";
    repo = "libbcrypt";
    rev = "55ff64349dec3012cfbbb1c4f92d4dbd46920213";
    hash = "sha256-OOur18pmAi84EVUlHI6HoIh0jgwvcI/rPXMNdSXzhj8=";
  };

  thirdPartySrc = fetchFromGitHub {
    owner = "litespeedtech";
    repo = "third-party";
    rev = "master";
    hash = "sha256-rUBPmDBbW1oKV7m47haM4aH4jBlw3N1uSSyduDydT7M=";
  };

  lsquicSrc = fetchFromGitHub {
    owner = "litespeedtech";
    repo = "lsquic";
    rev = "70486141724f85e97b08f510673e29f399bbae8f";
    hash = "sha256-mr3wajn8hFNe8f0t4friC1WHU5gfJv93Wa383OCXthk=";
    fetchSubmodules = true;
  };

  enableParallelBuilding = false;

  buildInputs = [
    libcap
    libxcrypt
    libaio
    luajit
    openssl
    pcre
  ];

  nativeBuildInputs = [
    breakpointHook
    cmake
  ];

  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail "add_definitions(-DRUN_TEST)" "    # add_definitions(-DRUN_TEST)" \
      --replace-fail "add_definitions(-DTEST_OUTPUT_PLAIN_CONF)" "# add_definitions(-DTEST_OUTPUT_PLAIN_CONF)" \
      --replace-fail "add_definitions(-DDEBUG_POOL)" "# add_definitions(-DDEBUG_POOL)" \
      --replace-fail "set(libUnitTest  libUnitTest++.a)" "# set(libUnitTest  libUnitTest++.a)" \
      --replace-fail "add_subdirectory(test)" "# add_subdirectory(test)"

    substituteInPlace src/CMakeLists.txt \
      --replace-fail "  set(STDCXX libstdc++.a)" "  set(STDCXX \"\")" \
      --replace-fail "-nodefaultlibs " ""

    substituteInPlace src/modules/modsecurity-ls/CMakeLists.txt \
      --replace-fail "-nodefaultlibs libstdc++.a" ""

    substituteInPlace src/modules/lua/CMakeLists.txt \
      --replace-fail "-nodefaultlibs libstdc++.a" ""

    substituteInPlace src/lsr/CMakeLists.txt \
      --replace-fail "   ls_llmq.c" "  # ls_llmq.c" \
      --replace-fail "   ls_llxq.c" "  # ls_llxq.c"
  '';

  postUnpack = ''
    # mkdir -p third-party
    # cp -r --no-preserve=mode ${thirdPartySrc}/. third-party
    # cp -r ${thirdPartySrc}/. third-party
    # chmod -R u+w third-party
    # mkdir -p third-party/include third-party/lib64 third-party/src
    echo "START POST UNPACK ${src}"
    mkdir -p ${pname}/third-party
    cp -r ${thirdPartySrc}/. ${pname}/third-party
    mkdir -p ${pname}/third-party/lib64
    mkdir -p ${pname}/third-party/include
    chmod -R u+w ${pname}/third-party

    #substituteInPlace ${pname}/third-party/script/build_ols.sh \
    #  --replace-fail "unittest-cpp" "bcrypt"
    #   --replace-fail "BUILD_LIBS=\"brotli zlib bssl bcrypt expat libaio ip2loc libmaxminddb luajit pcre psol udns bcrypt lmdb curl libxml2 yajl libmodsec\"" \
    #             "BUILD_LIBS=\"\"" \
    #   --replace-fail "git submodule update --init" "true" \
    #   --replace-fail "for BUILD_LIB in \$BUILD_LIBS" "for BUILD_LIB in \"\"" \
    #   --replace-fail "   ./build_$BUILD_LIB.sh" "   [ -n \"$BUILD_LIB\" ] && ./build_$BUILD_LIB.sh"
    cp -r --no-preserve=mode ${bcryptSrc} ${pname}/third-party/src/libbcrypt
    # chmod -R u+w third-party/src/libbcrypt
    pushd ${pname}/third-party/src/libbcrypt
    make
    echo "END MAKE"
    echo "START CP"
    cp bcrypt.h ../../include/
    cp bcrypt.a ../../lib64/libbcrypt.a

    #pushd ${pname}/third-party/script
    #./build_ols.sh
    popd
    echo "END POST UNPACK"
  '';

  cmakeFlags = [
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.14"
  ];

  meta = with lib; {
    homepage = "https://openlitepeed.org";
    changelog = "https://github.com/litespeedtech/openlitespeed/releases/tag/${src.tag}";
    description = "High performance, lightweight, open source HTTP server";
    license = licenses.gpl3;
    maintainers = with maintainers; [ sifmelcara ];
    platforms = platforms.all;
  };
}
