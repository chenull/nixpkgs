{
  lib,
  stdenv,
  boringssl,
  brotli,
  cmake,
  fetchFromGitHub,
  fetchzip,
  expat,
  curl,
  go,
  ip2location-c,
  libaio,
  libcap,
  lmdb,
  libmaxminddb,
  libmodsecurity,
  libxcrypt,
  libxml2,
  luajit,
  perl,
  pcre,
  udns,
  yajl,
  zlib,
  breakpointHook,
}:

let
  psolLegacy = stdenv.mkDerivation rec {
    pname = "psol";
    version = "1.11.33.4";

    src = fetchzip {
      url = "https://dl.google.com/dl/page-speed/psol/${version}.tar.gz";
      hash = "sha256-RhBvq8XlfqafzNOY+64lqSS/vRvY/bvJ5Fj5nSaWTRI=";
      stripRoot = false;
    };

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r psol/include $out/
      cp -r psol/lib $out/ || true
      if [ -d psol/lib64 ]; then
        cp -r psol/lib64 $out/
      fi

      install -d $out/include/pagespeed/kernel/base
      cat <<'EOF' > $out/include/pagespeed/kernel/base/scoped_ptr.h
/**
* Due the compiling issue, this file was updated from the original file.
*/
#ifndef PAGESPEED_KERNEL_BASE_SCOPED_PTR_H_
#define PAGESPEED_KERNEL_BASE_SCOPED_PTR_H_
#include "base/memory/scoped_ptr.h"

namespace net_instaweb {
template<typename T> class scoped_array : public scoped_ptr<T[]> {
public:
    scoped_array() : scoped_ptr<T[]>() {}
    explicit scoped_array(T* t) : scoped_ptr<T[]>(t) {}
};
}
#endif
EOF

      runHook postInstall
    '';
  };

in

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

  boringSslSrc = fetchFromGitHub {
    owner = "google";
    repo = "boringssl";
    rev = "9fc1c33e9c21439ce5f87855a6591a9324e569fd";
    hash = "sha256-JG+y3c1lKcmlOEHmKJMHf6b8FwAuP01vWHn8xzsJtKc=";
  };

  enableParallelBuilding = false;

  buildInputs = [
    boringssl
    brotli
    expat
    curl
    ip2location-c
    libaio
    libcap
    lmdb
    libmaxminddb
    libmodsecurity
    libxcrypt
    libxml2
    luajit
    pcre
    psolLegacy
    udns
    yajl
    zlib
  ];

  nativeBuildInputs = [
    breakpointHook
    cmake
    go
    perl
  ];

  postPatch = ''
    patchShebangs src/liblsquic/gen-verstrs.pl
    substituteInPlace CMakeLists.txt \
      --replace-fail "add_definitions(-DRUN_TEST)" "    # add_definitions(-DRUN_TEST)" \
      --replace-fail "add_definitions(-DTEST_OUTPUT_PLAIN_CONF)" "# add_definitions(-DTEST_OUTPUT_PLAIN_CONF)" \
      --replace-fail "add_definitions(-DDEBUG_POOL)" "# add_definitions(-DDEBUG_POOL)" \
      --replace-fail "set(libUnitTest  libUnitTest++.a)" "# set(libUnitTest  libUnitTest++.a)" \
      --replace-fail "add_subdirectory(test)" "# add_subdirectory(test)" \
      --replace-fail "set(BROTLI_ADD_LIB  libbrotlidec-static.a libbrotlienc-static.a libbrotlicommon-static.a)" \
                      "set(BROTLI_ADD_LIB  brotlidec brotlienc brotlicommon)" \
      --replace-fail "set(IP2LOC_ADD_LIB  libIP2Location.a)" \
                      "set(IP2LOC_ADD_LIB  IP2Location)"

    substituteInPlace src/CMakeLists.txt \
      --replace-fail "  set(STDCXX libstdc++.a)" "  set(STDCXX \"\")" \
      --replace-fail "-nodefaultlibs " "" \
      --replace-fail "libpcre.a" "pcre" \
      --replace-fail "libz.a" "z" \
      --replace-fail "libexpat.a" "expat" \
      --replace-fail "libxml2.a" "xml2"

    substituteInPlace test/CMakeLists.txt \
      --replace-fail "libz.a" "z" \
      --replace-fail "libexpat.a" "expat" \
      --replace-fail "libxml2.a" "xml2"

    substituteInPlace src/modules/modsecurity-ls/CMakeLists.txt \
      --replace-fail "-nodefaultlibs libstdc++.a" "" \
      --replace-fail "-lz" "z" \
      --replace-fail "-llmdb" "lmdb" \
      --replace-fail "-lxml2" "xml2" \
      --replace-fail "-lcurl" "curl" \
      --replace-fail "target_link_libraries(mod_security libmodsecurity.a" \
                     "target_link_libraries(mod_security modsecurity" \
      --replace-fail "-lyajl" "yajl"

    substituteInPlace src/modules/pagespeed/CMakeLists.txt \
      --replace-fail 'set(PSOL_LIB ''${PROJECT_SOURCE_DIR}/../third-party/psol-''${PSOL_VER})' \
                      "set(PSOL_LIB \"${psolLegacy}\")"

    sed -i 's|\(''${PSOL_LIB}/include/third_party/google-sparsehash/src\)|\1\n                ''${PSOL_LIB}/include/third_party/google-sparsehash/src/src|' \
      src/modules/pagespeed/CMakeLists.txt

    substituteInPlace src/modules/lua/CMakeLists.txt \
      --replace-fail "-nodefaultlibs libstdc++.a" "" \
      --replace-fail "target_link_libraries(mod_lua libluajit.a" \
                     "target_link_libraries(mod_lua luajit-5.1"

    substituteInPlace src/lsr/CMakeLists.txt \
      --replace-fail "   ls_llmq.c" "  # ls_llmq.c" \
      --replace-fail "   ls_llxq.c" "  # ls_llxq.c"
  '';

  # postPatch = ''
  #   substituteInPlace src/modules/pagespeed/CMakeLists.txt \
  #     --replace-fail 'set(PSOL_LIB ''${PROJECT_SOURCE_DIR}/../third-party/psol-''${PSOL_VER})' \
  #                     "set(PSOL_LIB \"${psol}\")"

  #   sed -i 's|\(''${PSOL_LIB}/include/third_party/google-sparsehash/src\)|\1\n                ''${PSOL_LIB}/include/third_party/google-sparsehash/src/src|' \
  #     src/modules/pagespeed/CMakeLists.txt
  # '';

  postUnpack = ''
    # prepare tmp dir for go build
    export GOCACHE=$TMPDIR/go-cache
    mkdir -p "$GOCACHE"

    # prepare third-party libraries
    mkdir -p third-party/lib64 third-party/include
    cp -r --no-preserve=mode ${thirdPartySrc}/. third-party

    # prepare lsquic library
    mkdir -p ${pname}/lsquic
    cp -r ${lsquicSrc}/. ${pname}/lsquic

    #substituteInPlace ${pname}/third-party/script/build_ols.sh \
    #  --replace-fail "unittest-cpp" "bcrypt"
    #   --replace-fail "BUILD_LIBS=\"brotli zlib bssl bcrypt expat libaio ip2loc libmaxminddb luajit pcre psol udns bcrypt lmdb curl libxml2 yajl libmodsec\"" \
    #             "BUILD_LIBS=\"\"" \
    #   --replace-fail "git submodule update --init" "true" \
    #   --replace-fail "for BUILD_LIB in \$BUILD_LIBS" "for BUILD_LIB in \"\"" \
    #   --replace-fail "   ./build_$BUILD_LIB.sh" "   [ -n \"$BUILD_LIB\" ] && ./build_$BUILD_LIB.sh"

    # prepare bcrypt library
    cp -r --no-preserve=mode ${bcryptSrc} third-party/src/libbcrypt
    pushd third-party/src/libbcrypt
    make
    cp bcrypt.h ../../include/
    cp bcrypt.a ../../lib64/libbcrypt.a

    #pushd ${pname}/third-party/script
    #./build_ols.sh
    popd

    rm -rf third-party/src/boringssl
    cp -r --no-preserve=mode ${boringSslSrc}/. third-party/src/boringssl
    chmod -R u+w third-party/src/boringssl

    pushd third-party/src/boringssl
    for patchFile in ../../patches/boringssl/bssl_lstls.patch \
                     ../../patches/boringssl/bssl_inttypes.patch; do
      patch -p1 < "$patchFile"
    done
    substituteInPlace CMakeLists.txt --replace-fail "-Werror" ""

    cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DCMAKE_C_FLAGS="-fPIC" -DCMAKE_CXX_FLAGS="-fPIC"
    cmake --build build --target crypto ssl decrepit -- -j''${NIX_BUILD_CORES:-1}

    cp build/crypto/libcrypto.a ../../../third-party/lib/libcrypto.a
    cp build/ssl/libssl.a ../../../third-party/lib/libssl.a
    cp build/decrepit/libdecrepit.a ../../../third-party/lib/libdecrepit.a

    rm -rf ../../include/openssl
    cp -r include/openssl ../../include/
    popd
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
    platforms = platforms.linux;
  };
}
