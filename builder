#!/bin/bash
#################################################
#	Title:	builder				#
#        Date:	2014-02-22			#
#     Version:	1.0				#
#      Author:	baho-utot@columbus.rr.com	#
#     Options:					#
#################################################
set -o errexit		# exit if error...insurance ;)
set -o nounset		# exit if variable not initalized
set +h			# disable hashall
PRGNAME=${0##*/}	# script name minus the path
#	Editable variables follow
LFS=/mnt/lfs		# where to build this animal
LFS_TGT=$(uname -m)-lfs-linux-gnu
PARENT="/usr/src/Octothorpe"
MKFLAGS="-j $(getconf _NPROCESSORS_ONLN)"
#	Edit partition and mnt_point for the correct values for your system
#	Failing to do so will cause you grief as in overwriting your system
#	You have been warned
#	the partition line is above the mount point ie sdb6 mounted at /
PARTITION=(	'sda6'	'sdxx'		) #sdxx	sdxx	sdxx	sdxx	sdxx	sdxx	)
MNT_POINT=(	'lfs'	'lfs/boot'	) #home	opt	tmp	usr	swap	usr/src	)
FILSYSTEM=(	'ext4'	'ext4'		) #ext4	ext4	ext4	ext4	swap	ext4	)
#
#	Common support functions
#
die() {
	local _red="\\033[1;31m"
	local _normal="\\033[0;39m"
	[ -n "$*" ] && printf "${_red}$*${_normal}\n"
	exit 1
}
msg() {
	printf "%s\n" "${1}"
}
msg_line() {
	printf "%s" "${1}"
}
msg_failure() {
	local _red="\\033[1;31m"
	local _normal="\\033[0;39m"
	printf "${_red}%s${_normal}\n" "FAILURE"
	exit 2
}
msg_success() {
	local _green="\\033[1;32m"
	local _normal="\\033[0;39m"
	printf "${_green}%s${_normal}\n" "SUCCESS"
	return 0
}
msg_log() {
	printf "\n%s\n\n" "${1}" >> ${_logfile} 2>&1
}
usage()	{
	msg	"Usage: ${PRGNAME} <options>"
	msg	"	-c - create filesystem(s)"
	msg	"	-m - mount filesystem(s)"
	msg	"	-u - unmount filesystem(s)"
	msg	"	-f - fetch source packages using wget"
	msg	"	-i - install build system to /mnt/lfs"
	msg 	"	-l - creates lfs user and sets environment"
	msg 	"	-r - removes lfs user"
	msg	"	-t - build toolchain"
	msg	"	-s - build system"
	msg 	"	-h - this info"
	exit 1
}
#
#	Support functions
#
build() {	# $1 = message 
		# $2 = command
		# $3 = log file
	local _msg="${1}"
	local _cmd="${2}"
	local _logfile="${3}"
	if [ "/dev/null" == "${_logfile}" ]; then
		#	Discard output no log file
		eval ${_cmd} >> ${_logfile} 2>&1
	else
		msg_line "       ${_msg}: "
		printf "\n%s\n\n" "###       ${_msg}       ###" >> ${_logfile} 2>&1
		eval ${_cmd} >> ${_logfile} 2>&1 && msg_success || msg_failure 
	fi
	return 0
}
unpack() {	# $1 = directory
		# $2 = source package name I'll find the suffix thank you
	local _dir=${1%%/BUILD*} # remove BUILD from path
	local i=${2}
	local p=$(echo ${_dir}/SOURCES/${i}*.tar.*)
	msg_line "       Unpacking: ${i}: "
	[ -e ${p} ] || die " File not found: FAILURE"
	tar xf ${p} && msg_success || msg_failure
	return 0
}
mount_filesystems() {
	local _logfile="/dev/null"
	if ! mountpoint ${LFS}/dev	>/dev/null 2>&1; then	mount --bind /dev ${LFS}/dev; fi
	if ! mountpoint ${LFS}/dev/pts	>/dev/null 2>&1; then	mount -t devpts devpts ${LFS}/dev/pts -o gid=5,mode=620; fi
	if ! mountpoint ${LFS}/proc	>/dev/null 2>&1; then	mount -t proc proc ${LFS}/proc; fi
	if ! mountpoint ${LFS}/sys 	>/dev/null 2>&1; then	mount -t sysfs sysfs ${LFS}/sys; fi
	if ! mountpoint ${LFS}/run	>/dev/null 2>&1; then	mount -t tmpfs tmpfs ${LFS}/run; fi
	if [ -h ${LFS}/dev/shm ];			 then	mkdir -pv ${LFS}/$(readlink ${LFS}/dev/shm); fi
	return 0
}
unmount_filesystems() {
	local _logfile="/dev/null"
	if mountpoint ${LFS}/run	>/dev/null 2>&1; then	umount ${LFS}/run; fi
	if mountpoint ${LFS}/sys	>/dev/null 2>&1; then	umount ${LFS}/sys; fi
	if mountpoint ${LFS}/proc	>/dev/null 2>&1; then	umount ${LFS}/proc; fi
	if mountpoint ${LFS}/dev/pts	>/dev/null 2>&1; then	umount ${LFS}/dev/pts; fi
	if mountpoint ${LFS}/dev	>/dev/null 2>&1; then	umount ${LFS}/dev; fi
	return 0
}
#
#	Build toolchain functions
#
chapter-5-04() {
	local	_pkgname="binutils"
	local	_pkgver="2.24"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Create work directory" "install -vdm 755 ../build" ${_logfile}
	build "Change directory: ../build" "pushd ../build" ${_logfile}
	build "Configure" "../${_pkgname}-${_pkgver}/configure --prefix=/tools --with-sysroot=${LFS} --with-lib-path=/tools/lib --target=${LFS_TGT} --disable-nls --disable-werror" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	[ "x86_64" == $(uname -m) ] && build "Create symlink for amd64" "install -vdm 755 /tools/lib;ln -vfs lib /tools/lib64" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}

chapter-5-05() {
	local	_pkgname="gcc"
	local	_pkgver="4.8.2"
	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	local	_pwd=${PWD}/BUILD
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	build "Create work directory" "install -vdm 755 build" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	unpack "${PWD}" "mpfr-3.1.2"
	unpack "${PWD}" "gmp-5.1.3"
	unpack "${PWD}" "mpc-1.0.2"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Symlinking gmp" " ln -vs ../gmp-5.1.3  gmp" ${_logfile}
	build "Symlinking mpc" " ln -vs ../mpc-1.0.2  mpc" ${_logfile}
	build "Symlinking mpfr" "ln -vs ../mpfr-3.1.2 mpfr" ${_logfile}
	build "Fixing headers" 'for file in $(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h); do cp -uv $file{,.orig};sed -e "s@/lib\(64\)\?\(32\)\?/ld@/tools&@g" -e "s@/usr@/tools@g" $file.orig > $file;printf "\n%s\n%s\n%s\n%s\n\n" "#undef STANDARD_STARTFILE_PREFIX_1" "#undef STANDARD_STARTFILE_PREFIX_2" "#define STANDARD_STARTFILE_PREFIX_1 \"/tools/lib/\"" "#define STANDARD_STARTFILE_PREFIX_2 \"\" ">> $file;touch $file.orig;done' ${_logfile}
	build "sed -i '/k prot/agcc_cv_libc_provides_ssp=yes' gcc/configure" "sed -i '/k prot/agcc_cv_libc_provides_ssp=yes' gcc/configure" ${_logfile}
	build "Change directory: ../build" "pushd ../build" ${_logfile}
	build "Configure" "../${_pkgname}-${_pkgver}/configure --target=${LFS_TGT} --prefix=/tools --with-sysroot=${LFS} --with-newlib --without-headers --with-local-prefix=/tools --with-native-system-header-dir=/tools/include --disable-nls --disable-shared --disable-multilib --disable-decimal-float --disable-threads --disable-libatomic --disable-libgomp --disable-libitm --disable-libmudflap --disable-libquadmath --disable-libsanitizer --disable-libssp --disable-libstdc++-v3 --enable-languages=c,c++ --with-mpfr-include=${_pwd}/${_pkgname}-${_pkgver}/mpfr/src --with-mpfr-lib=${_pwd}/build/mpfr/src/.libs" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Symlinking libgcc_eh.a" 'ln -vs libgcc.a $(${LFS_TGT}-gcc -print-libgcc-file-name | sed "s/libgcc/&_eh/")' ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-06() {
	local	_pkgname="linux"
	local	_pkgver="3.13.3"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "make mrproper" "make mrproper" ${_logfile}
	build "make headers_check" "make headers_check" ${_logfile}
	build "make INSTALL_HDR_PATH=dest headers_install" "make INSTALL_HDR_PATH=dest headers_install" ${_logfile}
	build "cp -rv dest/include/* /tools/include" "cp -rv dest/include/* /tools/include" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-07() {
	local	_pkgname="glibc"
	local	_pkgver="2.19"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	[ ! -r /usr/include/rpc/types.h ] && build "Copying rpc headers to host system" \
		"su -c 'mkdir -pv /usr/include/rpc' && su -c 'cp -v sunrpc/rpc/*.h /usr/include/rpc'"  ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Create work directory" "install -vdm 755 ../build" ${_logfile}
	build "Change directory: ../build" "pushd ../build" ${_logfile}
	build "Configure" "../${_pkgname}-${_pkgver}/configure --prefix=/tools --host=${LFS_TGT} --build=$(../${_pkgname}-${_pkgver}/scripts/config.guess) --disable-profile --enable-kernel=2.6.32 --with-headers=/tools/include libc_cv_forced_unwind=yes libc_cv_ctors_header=yes libc_cv_c_cleanup=yes" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	msg_line "       Checking glibc for sanity: "
	echo 'main(){}' > dummy.c
	${LFS_TGT}-gcc dummy.c
	retval=$(readelf -l a.out | grep ': /tools')
	rm dummy.c a.out
	#	[Requesting program interpreter: /tools/lib64/ld-linux-x86-64.so.2]
	retval=${retval##*: }	# strip [Requesting program interpreter: 
	retval=${retval%]}	# strip ]
	case "${retval}" in
		"/tools/lib/ld-linux.so.2")		msg_success ;;
		"/tools/lib64/ld-linux-x86-64.so.2")	msg_success ;;
		*)					msg_line "       Glibc is insane: "msg_failure ;;
	esac
	>  ${_complete}
	return 0
}
chapter-5-08() {
	local	_pkgname="gcc"
	local	_pkgver="4.8.2"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Create work directory" "install -vdm 755 ../build" ${_logfile}
	build "Change directory: ../build" "pushd ../build" ${_logfile}
	build "Configure" "../${_pkgname}-${_pkgver}/libstdc++-v3/configure --host=${LFS_TGT} --prefix=/tools --disable-multilib --disable-shared --disable-nls --disable-libstdcxx-threads --disable-libstdcxx-pch --with-gxx-include-dir=/tools/${LFS_TGT}/include/c++/${_pkgver}" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-09() {
	local	_pkgname="binutils"
	local	_pkgver="2.24"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Create work directory" "install -vdm 755 ../build" ${_logfile}
	build "Change directory: ../build" "pushd ../build" ${_logfile}
	build "Configure" "CC=${LFS_TGT}-gcc AR=${LFS_TGT}-ar RANLIB=${LFS_TGT}-ranlib ../${_pkgname}-${_pkgver}/configure --prefix=/tools --disable-nls --with-lib-path=/tools/lib --with-sysroot" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "make -C ld clean" "make -C ld clean" ${_logfile}
	build "make -C ld LIB_PATH=/usr/lib:/lib" "make -C ld LIB_PATH=/usr/lib:/lib" ${_logfile}
	build "cp -v ld/ld-new /tools/bin" "cp -v ld/ld-new /tools/bin" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-10() {
	local	_pkgname="gcc"
	local	_pkgver="4.8.2"
	local	_pwd=${PWD}/BUILD
	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	unpack "${PWD}" "mpfr-3.1.2"
	unpack "${PWD}" "gmp-5.1.3"
	unpack "${PWD}" "mpc-1.0.2"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Symlinking gmp" " ln -vs ../gmp-5.1.3  gmp" ${_logfile}
	build "Symlinking mpc" " ln -vs ../mpc-1.0.2  mpc" ${_logfile}
	build "Symlinking mpfr" "ln -vs ../mpfr-3.1.2 mpfr" ${_logfile}
	build "Fixing limits.h" 'cat gcc/limitx.h gcc/glimits.h gcc/limity.h > $(dirname $( ${LFS_TGT}-gcc -print-libgcc-file-name))/include-fixed/limits.h' ${_logfile}
	[ "x86_64" == $(uname -m) ] || build "Adding -fomit-frame-pointer to CFLAGS" 'sed -i "s/^T_CFLAGS =$/& -fomit-frame-pointer/" gcc/Makefile.in' ${_logfile}
	build "Fixing headers" 'for file in $(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h); do cp -uv $file{,.orig};sed -e "s@/lib\(64\)\?\(32\)\?/ld@/tools&@g" -e "s@/usr@/tools@g" $file.orig > $file;printf "\n%s\n%s\n%s\n%s\n\n" "#undef STANDARD_STARTFILE_PREFIX_1" "#undef STANDARD_STARTFILE_PREFIX_2" "#define STANDARD_STARTFILE_PREFIX_1 \"/tools/lib/\"" "#define STANDARD_STARTFILE_PREFIX_2 \"\" ">> $file;touch $file.orig;done' ${_logfile}			
	build "Create work directory" "install -vdm 755 ../build" ${_logfile}
	build "Change directory: ../build" "pushd ../build" ${_logfile}
	build "Configure" "CC=${LFS_TGT}-gcc CXX=${LFS_TGT}-g++ AR=${LFS_TGT}-ar RANLIB=${LFS_TGT}-ranlib ../${_pkgname}-${_pkgver}/configure --prefix=/tools --with-local-prefix=/tools --with-native-system-header-dir=/tools/include --enable-clocale=gnu --enable-shared --enable-threads=posix --enable-__cxa_atexit --enable-languages=c,c++ --disable-libstdcxx-pch --disable-multilib --disable-bootstrap --disable-libgomp --with-mpfr-include=${_pwd}/${_pkgname}-${_pkgver}/mpfr/src --with-mpfr-lib=${_pwd}/build/mpfr/src/.libs" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "ln -sv gcc /tools/bin/cc" "ln -sv gcc /tools/bin/cc" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	msg_line "       Checking glibc for sanity: "
	echo 'main(){}' > dummy.c
	${LFS_TGT}-gcc dummy.c
	retval=$(readelf -l a.out | grep ': /tools')
	rm dummy.c a.out
	#	[Requesting program interpreter: /tools/lib64/ld-linux-x86-64.so.2]
	retval=${retval##*: }	# strip [Requesting program interpreter: 
	retval=${retval%]}	# strip ]
	case "${retval}" in
		"/tools/lib/ld-linux.so.2")	     msg_success ;;
		"/tools/lib64/ld-linux-x86-64.so.2") msg_success ;;
		*)					msg_line "       GCC is insane: "msg_failure ;;
	esac
	>  ${_complete}
	return 0
}
chapter-5-11() {
	local	_pkgname="tcl"
	local	_pkgver="8.6.1"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}${_pkgver}-src"
	build "Change directory: ${_pkgname}${_pkgver}/unix" "pushd ${_pkgname}${_pkgver}/unix" ${_logfile}
	build "Configure" "./configure --prefix=/tools" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Installing Headers" "make install-private-headers" ${_logfile}
	build "chmod -v u+w /tools/lib/libtcl8.6.so" "chmod -v u+w /tools/lib/libtcl8.6.so" ${_logfile}
	build "ln -sv tclsh8.6 /tools/bin/tclsh" " ln -sv tclsh8.6 /tools/bin/tclsh" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-12() {
	local	_pkgname="expect"
	local	_pkgver="5.45"
	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}${_pkgver}"
	build "Change directory: ${_pkgname}${_pkgver}" "pushd ${_pkgname}${_pkgver}" ${_logfile}
	build "cp -v configure{,.orig}" "cp -v configure{,.orig}" ${_logfile}
	build "sed 's:/usr/local/bin:/bin:' configure.orig > configure" "sed 's:/usr/local/bin:/bin:' configure.orig > configure" ${_logfile}
	build "Configure" "./configure --prefix=/tools --with-tcl=/tools/lib --with-tclinclude=/tools/include" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" 'make SCRIPTS="" install' ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-13() {
	local	_pkgname="dejagnu"
	local	_pkgver="1.5.1"
	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/tools" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-14() {
	local	_pkgname="check"
	local	_pkgver="0.9.12"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "PKG_CONFIG= ./configure --prefix=/tools" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-15() {
	local	_pkgname="ncurses"
	local	_pkgver="5.9"
	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/tools --with-shared --without-debug --without-ada --enable-widec --enable-overwrite" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-16() {
	local	_pkgname="bash"
	local	_pkgver="4.2"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Patch" "patch -Np1 -i ../../SOURCES/bash-4.2-fixes-12.patch" ${_logfile}
	build "Configure" "./configure --prefix=/tools --without-bash-malloc" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "ln -sv bash /tools/bin/sh" "ln -sv bash /tools/bin/sh" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-17() {
	local	_pkgname="bzip2"
	local	_pkgver="1.0.6"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make  PREFIX=/tools install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-18() {
	local	_pkgname="coreutils"
	local	_pkgver="8.22"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/tools --enable-install-program=hostname" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-19() {
	local	_pkgname="diffutils"
	local	_pkgver="3.3"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/tools" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-20() {
	local	_pkgname="file"
	local	_pkgver="5.17"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/tools" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-21() {
	local	_pkgname="findutils"
	local	_pkgver="4.4.2"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/tools" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-22() {
	local	_pkgname="gawk"
	local	_pkgver="4.1.0"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/tools" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-23() {
	local	_pkgname="gettext"
	local	_pkgver="0.18.3.2"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}/gettext-tools" "pushd ${_pkgname}-${_pkgver}/gettext-tools" ${_logfile}
	build "Configure" "EMACS="no" ./configure --prefix=/tools --disable-shared" ${_logfile}
	build "make -C gnulib-lib" "make -C gnulib-lib" ${_logfile}
	build "make -C src msgfmt" "make -C src msgfmt" ${_logfile}
	build "make -C src msgmerge" "make -C src msgmerge" ${_logfile}
	build "make -C src xgettext" "make -C src xgettext" ${_logfile}
	build "cp -v src/{msgfmt,msgmerge,xgettext} /tools/bin" "cp -v src/{msgfmt,msgmerge,xgettext} /tools/bin" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-24() {
	local	_pkgname="grep"
	local	_pkgver="2.16"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "Configure" "./configure --prefix=/tools" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-25() {
	local	_pkgname="gzip"
	local	_pkgver="1.6"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "Configure" "./configure --prefix=/tools" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-26() {
	local	_pkgname="m4"
	local	_pkgver="1.4.17"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "Configure" "./configure --prefix=/tools" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-27() {
	local	_pkgname="make"
	local	_pkgver="4.0"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "Configure" "./configure --prefix=/tools --without-guile" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-28() {
	local	_pkgname="patch"
	local	_pkgver="2.7.1"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "Configure" "./configure --prefix=/tools" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-29() {
	local	_pkgname="perl"
	local	_pkgver="5.18.2"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "Patch" "patch -Np1 -i ../../SOURCES/perl-5.18.2-libc-1.patch" ${_logfile}
	build "Configure" "sh Configure -des -Dprefix=/tools" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile} 
	build "cp -v perl cpan/podlators/pod2man /tools/bin" "cp -v perl cpan/podlators/pod2man /tools/bin" ${_logfile}
	build "mkdir -pv /tools/lib/perl5/5.18.2" "mkdir -pv /tools/lib/perl5/5.18.2" ${_logfile}
	build "cp -Rv lib/* /tools/lib/perl5/5.18.2" "cp -Rv lib/* /tools/lib/perl5/5.18.2" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-30() {
	local	_pkgname="sed"
	local	_pkgver="4.2.2"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "Configure" "./configure --prefix=/tools" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-31() {
	local	_pkgname="tar"
	local	_pkgver="1.27.1"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "Configure" "./configure --prefix=/tools" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-32() {
	local	_pkgname="texinfo"
	local	_pkgver="5.2"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "Configure" "./configure --prefix=/tools" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-33() {
	local	_pkgname="util-linux"
	local	_pkgver="2.24.1"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "Configure" "./configure --prefix=/tools --disable-makeinstall-chown --without-systemdsystemunitdir PKG_CONFIG=''" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-34() {
	local	_pkgname="xz"
	local	_pkgver="5.0.5"
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "Configure" "./configure --prefix=/tools" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-5-35() {
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build 'strip --strip-debug /tools/lib/*' 'strip --strip-debug /tools/lib/* || true' ${_logfile}
	build '/usr/bin/strip --strip-unneeded /tools/{,s}bin/*' '/usr/bin/strip --strip-unneeded /tools/{,s}bin/* || true' ${_logfile}
	build 'rm -rf /tools/{,share}/{info,man,doc}' 'rm -rf /tools/{,share}/{info,man,doc}' ${_logfile}
	>  ${_complete}
	return 0
}
chapter-5-36() {
      	local	_complete="${PWD}/LOGS/${FUNCNAME}.completed"
	local	_logfile="${PWD}/LOGS/${FUNCNAME}.log"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "chown -R root:root $LFS/tools" "su -c 'chown -R root:root /mnt/lfs/tools'" ${_logfile}
	>  ${_complete}
	return 0
}
#
#	Build chapter 6
#
chapter-6-02() {
	local	_logfile="LOGS/${FUNCNAME}.log"
	local	_complete="LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Creating virtual kernel filesystem"
	> ${_logfile}
	msg "Create chroot filesystem "
	#	this is for kernel filesystem
	build "Creating /dev, /proc, /run and /sys filesystems" "install -vdm 755 ${LFS}/{dev,proc,run,sys,bin}" ${_logfile}
	build "Creating /dev/console" "mknod -m 600 ${LFS}/dev/console c 5 1" ${_logfile}
	build "Creating /dev/null" "mknod -m 600 ${LFS}/dev/null c 1 3" ${_logfile}
	build "Symlinking /tools/bash" "ln -vsf /tools/bin/bash ${LFS}/bin" ${_logfile}
	>  ${_complete}
	return 0
}
chapter-6-05() {
	local	_logfile="LOGS/${FUNCNAME}.log"
	local	_complete="LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Creating directories: bin,boot,etc/{opt,sysconfig},home,lib,mnt,opt" "install -vdm 755 /{bin,boot,etc/{opt,sysconfig},home,lib,mnt,opt}" ${_logfile}
	build "Creating directories: media/{floppy,cdrom},sbin,srv,var" "install -vdm 755 /{media/{floppy,cdrom},sbin,srv,var}" ${_logfile}
	build "Creating directory: /root" "install -dv -m 0750 /root" ${_logfile}
	build "Creating directories: /tmp /var/tmp" "install -dv -m 1777 /tmp /var/tmp" ${_logfile}
	build "Creating directories: /usr/{,local/}{bin,include,lib,sbin,src}" "install -vdm 755 /usr/{,local/}{bin,include,lib,sbin,src}" ${_logfile}
	build "Creating directories: /usr/{,local/}share/{color,dict,doc,info,locale,man}" "install -vdm 755 /usr/{,local/}share/{color,dict,doc,info,locale,man}" ${_logfile}
	build "Creating directories: /usr/{,local/}share/{misc,terminfo,zoneinfo}" "install -vdm 755 /usr/{,local/}share/{misc,terminfo,zoneinfo}" ${_logfile}
	build "Creating directory /usr/libexec" "install -vdm 755 /usr/libexec" ${_logfile}
	build "Creating directories: /usr/{,local/}share/man/man{1..8}" "install -vdm 755 /usr/{,local/}share/man/man{1..8}" ${_logfile}
	build "Symlinking: lib /lib64" "[ "x86_64" == "$(uname -m)" ] && ln -svf lib /lib64" ${_logfile}
	build "Symlinking: lib /usr/lib64" "[ "x86_64" == "$(uname -m)" ] && ln -svf lib /usr/lib64" ${_logfile}
	build "Symlinking: lib /usr/local/lib64" "[ "x86_64" == "$(uname -m)" ] && ln -svf lib /usr/local/lib64" ${_logfile}
	build "Creating directories: /var/{log,mail,spool}" "install -vdm 755 /var/{log,mail,spool}" ${_logfile}
	build "Symlinking: /run /var/run" "ln -svf /run /var/run" ${_logfile}
	build "Symlinking: /run/lock /var/lock" "ln -svf /run/lock /var/lock" ${_logfile}
	build "Creating directories: /var/{opt,cache,lib/{color,misc,locate},local}" "install -vdm 755 /var/{opt,cache,lib/{color,misc,locate},local}" ${_logfile}
	>  ${_complete}
	return 0
}
chapter-6-06() {
	local	_logfile="LOGS/${FUNCNAME}.log"
	local	_complete="LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	rm -f /bin/bash /bin/cat /bin/echo /bin/pwd /bin/stty || true
	build "Creating symlinks: /tools/bin/{bash,cat,echo,pwd,stty}" "ln -sv /tools/bin/{bash,cat,echo,pwd,stty} /bin"	${_logfile}
	build "Creating symlinks: /tools/bin/perl /usr/bin" "ln -sv /tools/bin/perl /usr/bin"				${_logfile}
	build "Creating symlinks: /tools/lib/libgcc_s.so{,.1}" "ln -sv /tools/lib/libgcc_s.so{,.1} /usr/lib"		${_logfile}
	build "Creating symlinks: /tools/lib/libstdc++.so{,.6} /usr/lib" "ln -sv /tools/lib/libstdc++.so{,.6} /usr/lib"	${_logfile}
	build "Sed: /usr/lib/libstdc++.la" "sed 's/tools/usr/' /tools/lib/libstdc++.la > /usr/lib/libstdc++.la"		${_logfile}
	build "Creating symlinks: bash /bin/sh" "ln -sv bash /bin/sh"							${_logfile}
	build "Creating symlinks: /proc/self/mounts /etc/mtab" "ln -sv /proc/self/mounts /etc/mtab"			${_logfile}
	cat > /etc/passwd <<- EOF
		root:x:0:0:root:/root:/bin/bash
		bin:x:1:1:bin:/dev/null:/bin/false
		nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
	EOF
	cat > /etc/group <<- "EOF"
		root:x:0:
		bin:x:1:
		sys:x:2:
		kmem:x:3:
		tape:x:4:
		tty:x:5:
		daemon:x:6:
		floppy:x:7:
		disk:x:8:
		lp:x:9:
		dialout:x:10:
		audio:x:11:
		video:x:12:
		utmp:x:13:
		usb:x:14:
		cdrom:x:15:
		mail:x:34:
		nogroup:x:99:
	EOF
	build "Touch: /var/log/{btmp,lastlog,wtmp}" "touch /var/log/{btmp,lastlog,wtmp}" ${_logfile}
	build "Chgrp: /var/log/lastlog" "chgrp -v utmp /var/log/lastlog" ${_logfile}
	build "Chmod: /var/log/lastlog" "chmod -v 664  /var/log/lastlog" ${_logfile}
	build "Chmod: /var/log/btmp" "chmod -v 600  /var/log/btmp" ${_logfile}
	>  ${_complete}
	return 0
}
chapter-6-07() {
	local	_pkgname="linux"
	local	_pkgver="3.13.3"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "make mrproper" "make mrproper" ${_logfile}
	build "make headers_check" "make headers_check" ${_logfile}
	build "make INSTALL_HDR_PATH=dest headers_install" "make INSTALL_HDR_PATH=dest headers_install" ${_logfile}
	build "find dest/include \( -name .install -o -name ..install.cmd \) -delete" "find dest/include \( -name .install -o -name ..install.cmd \) -delete" ${_logfile}
	build "cp -rv dest/include/* /usr/include" "cp -rv dest/include/* /usr/include" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-08() {
	local	_pkgname="man-pages"
	local	_pkgver="3.59"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "make install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-09.0() {
	local	_pkgname="glibc"
	local	_pkgver="2.19"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	sed -i 's/\\$$(pwd)/`pwd`/' timezone/Makefile
	build "Patch" "patch -Np1 -i ../../SOURCES/${_pkgname}-${_pkgver}-fhs-1.patch" ${_logfile}
	build "Create work directory" "install -vdm 755 ../build" ${_logfile}
	build "Change directory: ../build" "pushd ../build" ${_logfile}
	build "Configure" "../${_pkgname}-${_pkgver}/configure --prefix=/usr --disable-profile --enable-kernel=2.6.32 --enable-obsolete-rpc" ${_logfile}
	build "Make" "make ${MKFLAGS}" ${_logfile}
	build "touch /etc/ld.so.conf" "touch /etc/ld.so.conf" ${_logfile}
	build "make install" "make install" ${_logfile}
	build "Cp /etc/nscd.conf" "cp -v ../${_pkgname}-${_pkgver}/nscd/nscd.conf /etc/nscd.conf" ${_logfile}
	build "mkdir -pv /var/cache/nscd" "mkdir -pv /var/cache/nscd"							${_logfile}
	build "mkdir -pv /usr/lib/locale" "mkdir -pv /usr/lib/locale"							${_logfile}
	build "localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8" "localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8"			${_logfile}
	build "localedef -i de_DE -f ISO-8859-1 de_DE" "localedef -i de_DE -f ISO-8859-1 de_DE"				${_logfile}
	build "localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro" "localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro"	${_logfile}
	build "localedef -i de_DE -f UTF-8 de_DE.UTF-8" "localedef -i de_DE -f UTF-8 de_DE.UTF-8"			${_logfile}
	build "localedef -i en_GB -f UTF-8 en_GB.UTF-8" "localedef -i en_GB -f UTF-8 en_GB.UTF-8"			${_logfile}
	build "localedef -i en_HK -f ISO-8859-1 en_HK" "localedef -i en_HK -f ISO-8859-1 en_HK"				${_logfile}
	build "localedef -i en_PH -f ISO-8859-1 en_PH" "localedef -i en_PH -f ISO-8859-1 en_PH"				${_logfile}
	build "localedef -i en_US -f ISO-8859-1 en_US" "localedef -i en_US -f ISO-8859-1 en_US"				${_logfile}
	build "localedef -i en_US -f UTF-8 en_US.UTF-8" "localedef -i en_US -f UTF-8 en_US.UTF-8"			${_logfile}
	build "localedef -i es_MX -f ISO-8859-1 es_MX" "localedef -i es_MX -f ISO-8859-1 es_MX"				${_logfile}
	build "localedef -i fa_IR -f UTF-8 fa_IR" "localedef -i fa_IR -f UTF-8 fa_IR"					${_logfile}
	build "localedef -i fr_FR -f ISO-8859-1 fr_FR" "localedef -i fr_FR -f ISO-8859-1 fr_FR"				${_logfile}
	build "localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro" "localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro"	${_logfile}
	build "localedef -i fr_FR -f UTF-8 fr_FR.UTF-8" "localedef -i fr_FR -f UTF-8 fr_FR.UTF-8"			${_logfile}
	build "localedef -i it_IT -f ISO-8859-1 it_IT" "localedef -i it_IT -f ISO-8859-1 it_IT"				${_logfile}
	build "localedef -i it_IT -f UTF-8 it_IT.UTF-8" "localedef -i it_IT -f UTF-8 it_IT.UTF-8"			${_logfile}
	build "localedef -i ja_JP -f EUC-JP ja_JP" "localedef -i ja_JP -f EUC-JP ja_JP"					${_logfile}
	build "localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R" "localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R"			${_logfile}
	build "localedef -i ru_RU -f UTF-8 ru_RU.UTF-8" "localedef -i ru_RU -f UTF-8 ru_RU.UTF-8"			${_logfile}
	build "localedef -i tr_TR -f UTF-8 tr_TR.UTF-8" "localedef -i tr_TR -f UTF-8 tr_TR.UTF-8"			${_logfile}
	build "localedef -i zh_CN -f GB18030 zh_CN.GB18030" "localedef -i zh_CN -f GB18030 zh_CN.GB18030"		${_logfile}
	cat > /etc/nsswitch.conf <<- "EOF"
		# Begin /etc/nsswitch.conf
			passwd: files
			group: files
			shadow: files
			hosts: files dns
			networks: files
			protocols: files
			services: files
			ethers: files
			rpc: files
		# End /etc/nsswitch.conf
	EOF
	cat > /etc/ld.so.conf <<- "EOF"
		# Begin /etc/ld.so.conf
		/usr/local/lib
		/opt/lib
	EOF
	cat >> /etc/ld.so.conf <<- "EOF"
		# Add an include directory
		include /etc/ld.so.conf.d/*.conf
	EOF
	build "install -dm 755 /etc/ld.so.conf.d" "install -dm 755 /etc/ld.so.conf.d" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-09.1() {
	_pkgname="tzdata"
	_pkgver="2013i"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}${_pkgver}"
	ZONEINFO=/usr/share/zoneinfo
	build "install -vdm 755 $ZONEINFO/{posix,right}" "install -vdm 755 $ZONEINFO/{posix,right}" ${_logfile}
	build "Building time zones" 'for tz in etcetera southamerica northamerica europe africa antarctica asia australasia backward pacificnew systemv; do zic -L /dev/null   -d $ZONEINFO       -y "sh yearistype.sh" ${tz};zic -L /dev/null   -d $ZONEINFO/posix -y "sh yearistype.sh" ${tz};zic -L leapseconds -d $ZONEINFO/right -y "sh yearistype.sh" ${tz};done' ${_logfile}
	build "cp -v zone.tab iso3166.tab $ZONEINFO" "cp -v zone.tab iso3166.tab $ZONEINFO" ${_logfile}
	build "zic -d $ZONEINFO -p America/New_York" "zic -d $ZONEINFO -p America/New_York" ${_logfile}
	unset ZONEINFO
	build "cp -v /usr/share/zoneinfo/America/New_York /etc/localtime" "cp -v /usr/share/zoneinfo/America/New_York /etc/localtime" ${_logfile}
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-10() {
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	local	_check="${PARENT}/LOGS/${FUNCNAME}.check"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "v -v /tools/bin/{ld,ld-old}" "mv -v /tools/bin/{ld,ld-old}" ${_logfile}
	build "mv -v /tools/$(gcc -dumpmachine)/bin/{ld,ld-old}" "mv -v /tools/$(gcc -dumpmachine)/bin/{ld,ld-old}" ${_logfile}
	build "mv -v /tools/bin/{ld-new,ld}" "mv -v /tools/bin/{ld-new,ld}" ${_logfile}
	build "ln -sv /tools/bin/ld /tools/$(gcc -dumpmachine)/bin/ld" 'ln -sv /tools/bin/ld /tools/$(gcc -dumpmachine)/bin/ld' ${_logfile}
	build "Create specs file" "gcc -dumpspecs | sed -e 's|/tools||g' -e '/\*startfile_prefix_spec:/{n;s|.*|/usr/lib/ |}' -e '/\*cpp:/{n;s|$| -isystem /usr/include|}' > $(dirname $(gcc --print-libgcc-file-name))/specs" ${_logfile}
	build "echo 'main(){}' > dummy.c" "echo 'main(){}' > dummy.c" ${_check}
	build "cc dummy.c -v -Wl,--verbose &> dummy.log" "cc dummy.c -v -Wl,--verbose &> dummy.log" ${_check}
	build "readelf -l a.out | grep ': /lib'" "readelf -l a.out | grep ': /lib'" ${_check}
	build "grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log" "grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log" ${_check}
	build "grep -B1 '^ /usr/include' dummy.log" "grep -B1 '^ /usr/include' dummy.log" ${_check}
	build "grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'" "grep 'SEARCH.*/usr/lib' dummy.log | sed 's|; |\n|g'" ${_check}
	build 'grep /lib.*/libc.so.6 dummy.log' "grep '/lib.*/libc.so.6 ' dummy.log" ${_check}
	build "grep found dummy.log" "grep found dummy.log" ${_check}
	build "rm -v dummy.c a.out dummy.log" "rm -v dummy.c a.out dummy.log" ${_check}
	>  ${_complete}
	return 0
}
chapter-6-11() {
	local	_pkgname="zlib"
	local	_pkgver="1.2.8"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "mv -v /usr/lib/libz.so.* /lib" "mv -v /usr/lib/libz.so.* /lib" ${_logfile}
	build "ln -sfv ../../lib/$(readlink /usr/lib/libz.so) /usr/lib/libz.so" "ln -sfv ../../lib/$(readlink /usr/lib/libz.so) /usr/lib/libz.so" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-12() {
	local	_pkgname="file"
	local	_pkgver="5.17"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-13() {
	local	_pkgname="binutils"
	local	_pkgver="2.24"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "rm -fv etc/standards.info" "rm -fv etc/standards.info" ${_logfile}
	build "sed -i.bak '/^INFO/s/standards.info //' etc/Makefile.in" "sed -i.bak '/^INFO/s/standards.info //' etc/Makefile.in" ${_logfile}
	build "Create work directory" "install -vdm 755 ../build" ${_logfile}
	build "Change directory: ../build" "pushd ../build" ${_logfile}
	build "Configure" "../binutils-2.24/configure --prefix=/usr  --enable-shared" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS} tooldir=/usr" ${_logfile}
	build "Install" "make tooldir=/usr install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-14() {
	local	_pkgname="gmp"
	local	_pkgver="5.1.3"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	[ "i686" == "$(uname -m)" ]	&& build "Configure" ".ABI=32 /configure --prefix=/usr --enable-cxx" ${_logfile}
	[ "x86_64" == "$(uname -m)" ]	&& build "Configure" "./configure --prefix=/usr --enable-cxx" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "mkdir -v /usr/share/doc/gmp-5.1.3" "mkdir -v /usr/share/doc/gmp-5.1.3" ${_logfile}
	build "cp    -v doc/{isa_abi_headache,configuration} doc/*.html /usr/share/doc/gmp-5.1.3" "cp    -v doc/{isa_abi_headache,configuration} doc/*.html /usr/share/doc/gmp-5.1.3" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-15() {
	local	_pkgname="mpfr"
	local	_pkgver="3.1.2"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr --enable-thread-safe --docdir=/usr/share/doc/mpfr-3.1.2" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "make html" "make html" ${_logfile}
	build "make install-html" "make install-html" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-16() {
	local	_pkgname="mpc"
	local	_pkgver="1.0.2"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-17() {
	local	_pkgname="gcc"
	local	_pkgver="4.8.2"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	local	_check="${PARENT}/LOGS/${FUNCNAME}.check"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	case $(uname -m) in
		i?86) build "sed -i 's/^T_CFLAGS =$/& -fomit-frame-pointer/' gcc/Makefile.in" "sed -i 's/^T_CFLAGS =$/& -fomit-frame-pointer/' gcc/Makefile.in" ${_logfile} ;;
	esac
	build "sed -i -e /autogen/d -e /check.sh/d fixincludes/Makefile.in" "sed -i -e /autogen/d -e /check.sh/d fixincludes/Makefile.in" ${_logfile}
	build "mv -v libmudflap/testsuite/libmudflap.c++/pass41-frag.cxx{,.disable}" "mv -v libmudflap/testsuite/libmudflap.c++/pass41-frag.cxx{,.disable}" ${_logfile}
	build "Create work directory" "install -vdm 755 ../build" ${_logfile}
	build "Change directory: ../build" "pushd ../build" ${_logfile}
	build "Configure" "SED=sed ../${_pkgname}-${_pkgver}/configure --prefix=/usr --enable-shared --enable-threads=posix --enable-__cxa_atexit --enable-clocale=gnu --enable-languages=c,c++ --disable-multilib --disable-bootstrap  --with-system-zlib" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "ln -sv ../usr/bin/cpp /lib" "ln -sv ../usr/bin/cpp /lib" ${_logfile}
	build "ln -sv gcc /usr/bin/cc" "ln -sv gcc /usr/bin/cc" ${_logfile}
	build "echo 'main(){}' > dummy.c" "echo 'main(){}' > dummy.c" ${_check}
	build "cc dummy.c -v -Wl,--verbose &> dummy.log" "cc dummy.c -v -Wl,--verbose &> dummy.log" ${_check}
	build "readelf -l a.out | grep ': /lib'" "readelf -l a.out | grep ': /lib'" ${_check}
	build "grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log" "grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log" ${_check}
	build "grep -B4 '^ /usr/include' dummy.log" "grep -B4 '^ /usr/include' dummy.log" ${_check}
	build "grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'" "grep 'SEARCH.*/usr/lib' dummy.log | sed 's|; |\n|g'" ${_check}
	build 'grep /lib.*/libc.so.6 dummy.log' "grep '/lib.*/libc.so.6 ' dummy.log" ${_check}
	build "grep found dummy.log" "grep found dummy.log" ${_check}
	build "rm -v dummy.c a.out dummy.log" "rm -v dummy.c a.out dummy.log" ${_check}
	build "mkdir -pv /usr/share/gdb/auto-load/usr/lib" "mkdir -pv /usr/share/gdb/auto-load/usr/lib" ${_logfile}
	build "mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib" "mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-18() {
	local	_pkgname="sed"
	local	_pkgver="4.2.2"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr --bindir=/bin --htmldir=/usr/share/doc/${_pkgname}-${_pkgver}" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "make html" "make html" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "make -C doc install-html" "make -C doc install-html" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-19() {
	local	_pkgname="bzip2"
	local	_pkgver="1.0.6"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Patch" "patch -Np1 -i ../../SOURCES/bzip2-1.0.6-install_docs-1.patch" ${_logfile}
	build 'sed -i "s@\(ln -s -f \)$(PREFIX)/bin/@\1@" Makefile' 'sed -i "s@\(ln -s -f \)$(PREFIX)/bin/@\1@" Makefile' ${_logfile}
	build 'sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile' 'sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile' ${_logfile}
	build "Make" "make V=1 ${MKFLAGS} -f Makefile-libbz2_so" ${_logfile}
	build "Make" "make clean" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make PREFIX=/usr install" ${_logfile}
	build "cp -v bzip2-shared /bin/bzip2" "cp -v bzip2-shared /bin/bzip2" ${_logfile}
	build "cp -av libbz2.so* /lib" "cp -av libbz2.so* /lib" ${_logfile}
	build "ln -sv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so" "ln -sv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so" ${_logfile}
	build "rm -v /usr/bin/{bunzip2,bzcat,bzip2}" "rm -v /usr/bin/{bunzip2,bzcat,bzip2}" ${_logfile}
	build "ln -sv bzip2 /bin/bunzip2" "ln -sv bzip2 /bin/bunzip2" ${_logfile}
	build "ln -sv bzip2 /bin/bzcat" "ln -sv bzip2 /bin/bzcat" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-20() {
	local	_pkgname="pkg-config"
	local	_pkgver="0.28"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr --with-internal-glib --disable-host-tool --docdir=/usr/share/doc/pkg-config-0.28" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-21() {
	local	_pkgname="ncurses"
	local	_pkgver="5.9"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr --mandir=/usr/share/man --with-shared --without-debug --enable-pc-files --enable-widec" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "mv -v /usr/lib/libncursesw.so.5* /lib" "mv -v /usr/lib/libncursesw.so.5* /lib" ${_logfile}
	build "ln -sfv ../../lib/$(readlink /usr/lib/libncursesw.so) /usr/lib/libncursesw.so" "ln -sfv ../../lib/$(readlink /usr/lib/libncursesw.so) /usr/lib/libncursesw.so" ${_logfile}
	build "Fixing libraries/pkg-config files" 'for lib in ncurses form panel menu ; do rm -vf /usr/lib/lib${lib}.so; echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so;ln -sfv lib${lib}w.a /usr/lib/lib${lib}.a;ln -sfv ${lib}w.pc /usr/lib/pkgconfig/${lib}.pc; done' ${_logfile}
	build "ln -sfv libncurses++w.a /usr/lib/libncurses++.a" "ln -sfv libncurses++w.a /usr/lib/libncurses++.a" ${_logfile}
	build "rm -vf /usr/lib/libcursesw.so" "rm -vf /usr/lib/libcursesw.so" ${_logfile}
	build 'echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so' 'echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so' ${_logfile}
	build "ln -sfv libncurses.so /usr/lib/libcurses.so" "ln -sfv libncurses.so /usr/lib/libcurses.so" ${_logfile}
	build "ln -sfv libncursesw.a /usr/lib/libcursesw.a" "ln -sfv libncursesw.a /usr/lib/libcursesw.a" ${_logfile}
	build "ln -sfv libncurses.a  /usr/lib/libcurses.a" "ln -sfv libncurses.a /usr/lib/libcurses.a" ${_logfile}
	build "mkdir -v /usr/share/doc/ncurses-5.9" "mkdir -v /usr/share/doc/ncurses-5.9" ${_logfile}
	build "cp -v -R doc/* /usr/share/doc/ncurses-5.9" "cp -v -R doc/* /usr/share/doc/ncurses-5.9" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-22() {
	local	_pkgname="shadow"
	local	_pkgver="4.1.5.1"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}_${_pkgver}.orig"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "sed -i 's/groups$(EXEEXT) //' src/Makefile.in" "sed -i 's/groups$(EXEEXT) //' src/Makefile.in" ${_logfile}
	build "find man -name Makefile.in -exec sed -i 's/groups\.1 / /' {} \;" "find man -name Makefile.in -exec sed -i 's/groups\.1 / /' {} \;" ${_logfile}
	build "sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@  etc/login.defs'" "sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@'  etc/login.defs" ${_logfile}
	build "sed -i -e 's@/var/spool/mail@/var/mail@' etc/login.defs" "sed -i -e 's@/var/spool/mail@/var/mail@' etc/login.defs" ${_logfile}
	build "Configure" "./configure --sysconfdir=/etc" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "mv -v /usr/bin/passwd /bin" "mv -v /usr/bin/passwd /bin" ${_logfile}
	build "Converting passwords" "pwconv" ${_logfile}
	build "Converting groups" "grpconv" ${_logfile}
	build "sed -i 's/yes/no/' /etc/default/useradd" "sed -i 's/yes/no/' /etc/default/useradd" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-23() {
	local	_pkgname="psmisc"
	local	_pkgver="22.20"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "mv -v /usr/bin/fuser /bin" "mv -v /usr/bin/fuser /bin" ${_logfile}
	build "mv -v /usr/bin/killall /bin" "mv -v /usr/bin/killall /bin" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-24() {
	local	_pkgname="procps-ng"
	local	_pkgver="3.3.9"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr --exec-prefix= --libdir=/usr/lib --docdir=/usr/share/doc/procps-ng-3.3.9 --disable-static --disable-kill" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "sed -i -r 's|(pmap_initname)\\\$|\1|' testsuite/pmap.test/pmap.exp" "sed -i -r 's|(pmap_initname)\\\$|\1|' testsuite/pmap.test/pmap.exp" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "mv -v /usr/bin/pidof /bin" "mv -v /usr/bin/pidof /bin" ${_logfile}
	build "mv -v /usr/lib/libprocps.so.* /lib" "mv -v /usr/lib/libprocps.so.* /lib" ${_logfile}
	build "ln -sfv ../../lib/$(readlink /usr/lib/libprocps.so) /usr/lib/libprocps.so" "ln -sfv ../../lib/$(readlink /usr/lib/libprocps.so) /usr/lib/libprocps.so" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-25() {
	local	_pkgname="e2fsprogs"
	local	_pkgver="1.42.9"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "sed -i -e 's|^LD_LIBRARY_PATH.*|&:/tools/lib|' tests/test_config" "sed -i -e 's|^LD_LIBRARY_PATH.*|&:/tools/lib|' tests/test_config" ${_logfile}
	build "Create work directory" "install -vdm 755 build" ${_logfile}
	build "Change directory: ../build" "pushd build" ${_logfile}
	build "Configure" "LIBS=-L/tools/lib CFLAGS=-I/tools/include PKG_CONFIG_PATH=/tools/lib/pkgconfig ../configure --prefix=/usr --with-root-prefix='' --enable-elf-shlibs --disable-libblkid --disable-libuuid --disable-uuidd --disable-fsck" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "make install-libs" "make install-libs" ${_logfile}
	build "chmod -v u+w /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a" "chmod -v u+w /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a" ${_logfile}
	build "gunzip -v /usr/share/info/libext2fs.info.gz" "gunzip -v /usr/share/info/libext2fs.info.gz" ${_logfile}
	build "install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info" "install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info" ${_logfile}
	build "makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo" "makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo" ${_logfile}
	build "install -v -m644 doc/com_err.info /usr/share/info" "install -v -m644 doc/com_err.info /usr/share/info" ${_logfile}
	build "install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info" "install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info" ${_logfile}
	build "Restore directory" "popd " ${_logfile}
	build "Restore directory" "popd " ${_logfile}
	build "Restore directory" "popd " ${_logfile}
	>  ${_complete}
	return 0
}
chapter-6-26() {
	local	_pkgname="coreutils"
	local	_pkgver="8.22"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Patching" "patch -Np1 -i ../../SOURCES/coreutils-8.22-i18n-4.patch" ${_logfile}
	build "Configure" "FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr --enable-no-install-program=kill,uptime" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "mv -v /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin" "mv -v /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin" ${_logfile}
	build "mv -v /usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /bin" "mv -v /usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /bin" ${_logfile}
	build "mv -v /usr/bin/{rmdir,stty,sync,true,uname,test,[} /bin" "mv -v /usr/bin/{rmdir,stty,sync,true,uname,test,[} /bin" ${_logfile}
	build "mv -v /usr/bin/chroot /usr/sbin" "mv -v /usr/bin/chroot /usr/sbin" ${_logfile}
	build "mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8" "mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8" ${_logfile}
	build 'sed -i s/\"1\"/\"8\"/1 /usr/share/man/man8/chroot.8' 'sed -i s/\"1\"/\"8\"/1 /usr/share/man/man8/chroot.8' ${_logfile}
	build "mv -v /usr/bin/{head,sleep,nice} /bin" "mv -v /usr/bin/{head,sleep,nice} /bin" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-27() {
	local	_pkgname="iana-etc"
	local	_pkgver="2.30"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-28() {
	local	_pkgname="m4"
	local	_pkgver="1.4.17"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "Configure" "./configure --prefix=/usr" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-29() {
	local	_pkgname="flex"
	local	_pkgver="2.5.38"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "sed -i -e '/test-bison/d' tests/Makefile.in" "sed -i -e '/test-bison/d' tests/Makefile.in" ${_logfile}
	build "Configure" "./configure  --prefix=/usr --docdir=/usr/share/doc/flex-2.5.38" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	cat > /usr/bin/lex <<- "EOF"
		#!/bin/sh
		# Begin /usr/bin/lex
	
		exec /usr/bin/flex -l "$@"
	
		# End /usr/bin/lex
	EOF
	build "chmod -v 755 /usr/bin/lex" "chmod -v 755 /usr/bin/lex" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-30() {
	local	_pkgname="bison"
	local	_pkgver="3.0.2"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "Configure" "./configure --prefix=/usr" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-31() {
	local	_pkgname="grep"
	local	_pkgver="2.16"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "Configure" "./configure --prefix=/usr --bindir=/bin" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-32() {
	local	_pkgname="readline"
	local	_pkgver="6.2"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "sed -i '/MV.*old/d' Makefile.in" "sed -i '/MV.*old/d' Makefile.in" ${_logfile}
	build "sed -i '/{OLDSUFF}/c:' support/shlib-install" "sed -i '/{OLDSUFF}/c:' support/shlib-install" ${_logfile}
	build "Patching" "patch -Np1 -i ../../SOURCES/readline-6.2-fixes-2.patch" ${_logfile}
	build "Configure" "./configure --prefix=/usr" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS} SHLIB_LIBS=-lncurses" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "mv -v /usr/lib/lib{readline,history}.so.* /lib" "mv -v /usr/lib/lib{readline,history}.so.* /lib" ${_logfile}
	build "ln -sfv ../../lib/$(readlink /usr/lib/libreadline.so) /usr/lib/libreadline.so" "ln -sfv ../../lib/$(readlink /usr/lib/libreadline.so) /usr/lib/libreadline.so" ${_logfile}
	build "ln -sfv ../../lib/$(readlink /usr/lib/libhistory.so ) /usr/lib/libhistory.so" "ln -sfv ../../lib/$(readlink /usr/lib/libhistory.so ) /usr/lib/libhistory.so" ${_logfile}
	build "mkdir   -v /usr/share/doc/readline-6.2" "mkdir   -v /usr/share/doc/readline-6.2" ${_logfile}
	build "install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-6.2" "install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-6.2" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-33() {
	local	_pkgname="bash"
	local	_pkgver="4.2"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "Patching" "patch -Np1 -i ../../SOURCES/bash-4.2-fixes-12.patch" ${_logfile}
	build "Configure" "./configure --prefix=/usr --bindir=/bin --htmldir=/usr/share/doc/bash-4.2 --without-bash-malloc --with-installed-readline" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-34() {
	local	_pkgname="bc"
	local	_pkgver="1.06.95"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "Configure" "./configure --prefix=/usr --with-readline --mandir=/usr/share/man --infodir=/usr/share/info" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-35() {
	local	_pkgname="libtool"
	local	_pkgver="2.4.2"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "Configure" "./configure --prefix=/usr" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-36() {
	local	_pkgname="gdbm"
	local	_pkgver="1.11"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}	
	build "Configure" "./configure --prefix=/usr" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-37() {
	local	_pkgname="inetutils"
	local	_pkgver="1.9.2"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "echo '#define PATH_PROCNET_DEV "/proc/net/dev"' >> ifconfig/system/linux.h " "echo '#define PATH_PROCNET_DEV \"/proc/net/dev\"' >> ifconfig/system/linux.h " ${_logfile}
	build "Configure" "./configure --prefix=/usr --localstatedir=/var --disable-logger --disable-syslogd --disable-whois --disable-servers" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "mv -v /usr/bin/{hostname,ping,ping6,traceroute} /bin" "mv -v /usr/bin/{hostname,ping,ping6,traceroute} /bin" ${_logfile}
	build "mv -v /usr/bin/ifconfig /sbin" "mv -v /usr/bin/ifconfig /sbin" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-38() {
	local	_pkgname="perl"
	local	_pkgver="5.18.2"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build 'echo "127.0.0.1 localhost $(hostname)" > /etc/hosts' 'echo "127.0.0.1 localhost $(hostname)" > /etc/hosts' ${_logfile}
	build "sed -i 's|BUILD_ZLIB\s*= True|BUILD_ZLIB = False|' cpan/Compress-Raw-Zlib/config.in" "sed -i 's|BUILD_ZLIB\s*= True|BUILD_ZLIB = False|' cpan/Compress-Raw-Zlib/config.in" ${_logfile}
	build "sed -i 's|INCLUDE\s*= ./zlib-src|INCLUDE    = /usr/include|' cpan/Compress-Raw-Zlib/config.in" "sed -i 's|INCLUDE\s*= ./zlib-src|INCLUDE    = /usr/include|' cpan/Compress-Raw-Zlib/config.in" ${_logfile}
	build "sed -i 's|LIB\s*= ./zlib-src|LIB        = /usr/lib|' cpan/Compress-Raw-Zlib/config.in" "sed -i 's|LIB\s*= ./zlib-src|LIB        = /usr/lib|' cpan/Compress-Raw-Zlib/config.in" ${_logfile}
	build "Configure" 'sh Configure -des -Dprefix=/usr -Dvendorprefix=/usr -Dman1dir=/usr/share/man/man1 -Dman3dir=/usr/share/man/man3 -Dpager="/usr/bin/less -isR" -Duseshrplib' ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-39() {
	local	_pkgname="autoconf"
	local	_pkgver="2.69"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr " ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-40() {
	local	_pkgname="automake"
	local	_pkgver="1.14.1"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr --docdir=/usr/share/doc/${_pkgname}-${_pkgver}" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "sed -i 's:./configure:LEXLIB=/usr/lib/libfl.a &:' t/lex-{clean,depend}-cxx.sh" "sed -i 's:./configure:LEXLIB=/usr/lib/libfl.a &:' t/lex-{clean,depend}-cxx.sh" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-41() {
	local	_pkgname="diffutils"
	local	_pkgver="3.3"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "sed -i 's:= @mkdir_p@:= /bin/mkdir -p:' po/Makefile.in.in" "sed -i 's:= @mkdir_p@:= /bin/mkdir -p:' po/Makefile.in.in" ${_logfile}
	build "Configure" "./configure --prefix=/usr " ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-42() {
	local	_pkgname="gawk"
	local	_pkgver="4.1.0"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr " ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "mkdir -v /usr/share/doc/${_pkgname}-${_pkgver}" "mkdir -v /usr/share/doc/${_pkgname}-${_pkgver}" ${_logfile}
	build "cp -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/${_pkgname}-${_pkgver}" "cp -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/${_pkgname}-${_pkgver}" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-43() {
	local	_pkgname="findutils"
	local	_pkgver="4.4.2"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr --localstatedir=/var/lib/locate" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "mv -v /usr/bin/find /bin" "mv -v /usr/bin/find /bin" ${_logfile}
	build "sed -i 's/find:=\${BINDIR}/find:=\/bin/' /usr/bin/updatedb" "sed -i 's/find:=\${BINDIR}/find:=\/bin/' /usr/bin/updatedb" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-44() {
	local	_pkgname="gettext"
	local	_pkgver="0.18.3.2"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr --docdir=/usr/share/doc/${_pkgname}-${_pkgver}" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-45() {
	local	_pkgname="groff"
	local	_pkgver="1.22.2"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "PAGE=letter ./configure --prefix=/usr " ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "ln -sv eqn /usr/bin/geqn" "ln -sv eqn /usr/bin/geqn" ${_logfile}
	build "ln -sv tbl /usr/bin/gtbl" "ln -sv tbl /usr/bin/gtbl" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-46() {
	local	_pkgname="xz"
	local	_pkgver="5.0.5"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr --docdir=/usr/share/doc/${_pkgname}-${_pkgver}" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "mv -v   /usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin" "mv -v   /usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin" ${_logfile}
	build "mv -v /usr/lib/liblzma.so.* /lib" "mv -v /usr/lib/liblzma.so.* /lib" ${_logfile}
	build "ln -svf ../../lib/$(readlink /usr/lib/liblzma.so) /usr/lib/liblzma.so" "ln -svf ../../lib/$(readlink /usr/lib/liblzma.so) /usr/lib/liblzma.so" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-47() {
	local	_pkgname="grub"
	local	_pkgver="2.00"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "sed -i -e '/gets is a/d' grub-core/gnulib/stdio.in.h" "sed -i -e '/gets is a/d' grub-core/gnulib/stdio.in.h" ${_logfile}
	build "Configure" "./configure --prefix=/usr --sbindir=/sbin --sysconfdir=/etc --disable-grub-emu-us --disable-efiemu --disable-werror" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-48() {
	local	_pkgname="less"
	local	_pkgver="458"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr --sysconfdir=/etc" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-49() {
	local	_pkgname="gzip"
	local	_pkgver="1.6"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr --bindir=/bin" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "mv -v /bin/{gzexe,uncompress,zcmp,zdiff,zegrep} /usr/bin" "mv -v /bin/{gzexe,uncompress,zcmp,zdiff,zegrep} /usr/bin" ${_logfile}
	build "mv -v /bin/{zfgrep,zforce,zgrep,zless,zmore,znew} /usr/bin" "mv -v /bin/{zfgrep,zforce,zgrep,zless,zmore,znew} /usr/bin" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-50() {
	local	_pkgname="iproute2"
	local	_pkgver="3.12.0"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "sed -i '/^TARGETS/s@arpd@@g' misc/Makefile" "sed -i '/^TARGETS/s@arpd@@g' misc/Makefile" ${_logfile}
	build "sed -i /ARPD/d Makefile" "sed -i /ARPD/d Makefile" ${_logfile}
	build "sed -i 's/arpd.8//' man/man8/Makefile" "sed -i 's/arpd.8//' man/man8/Makefile" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS} DESTDIR=" ${_logfile}
	build "Install" "make DESTDIR=  MANDIR=/usr/share/man  DOCDIR=/usr/share/doc/${_pkgname}-${_pkgver} install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-51() {
	local	_pkgname="kbd"
	local	_pkgver="2.0.1"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Patch" "patch -Np1 -i ../../SOURCES/kbd-2.0.1-backspace-1.patch" ${_logfile}
	build "sed -i 's/\(RESIZECONS_PROGS=\)yes/\1no/g' configure" "sed -i 's/\(RESIZECONS_PROGS=\)yes/\1no/g' configure" ${_logfile}
	build "sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in" "sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in" ${_logfile}
	build "Configure" "PKG_CONFIG_PATH=/tools/lib/pkgconfig ./configure --prefix=/usr --disable-vlock" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "mkdir -v       /usr/share/doc/${_pkgname}-${_pkgver}" "mkdir -v       /usr/share/doc/${_pkgname}-${_pkgver}" ${_logfile}
	build "cp -R -v docs/doc/* /usr/share/doc/${_pkgname}-${_pkgver}" "cp -R -v docs/doc/* /usr/share/doc/${_pkgname}-${_pkgver}" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-52() {
	local	_pkgname="kmod"
	local	_pkgver="16"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr --bindir=/bin --sysconfdir=/etc --with-rootlibdir=/lib --disable-manpages --with-xz --with-zlib" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "make -C man install" "make -C man install" ${_logfile}
	build 'for target in depmod insmod modinfo modprobe rmmod; do ln -sv ../bin/kmod /sbin/$target;done;' 'for target in depmod insmod modinfo modprobe rmmod; do ln -sv ../bin/kmod /sbin/${target}; done;' ${_logfile}
	build "ln -sv kmod /bin/lsmod" "ln -sv kmod /bin/lsmod" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-53() {
	local	_pkgname="libpipeline"
	local	_pkgver="1.2.6"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "PKG_CONFIG_PATH=/tools/lib/pkgconfig ./configure --prefix=/usr " ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-54() {
	local	_pkgname="make"
	local	_pkgver="4.0"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr " ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-55() {
	local	_pkgname="patch"
	local	_pkgver="2.7.1"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr " ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-56() {
	local	_pkgname="sysklogd"
	local	_pkgver="1.5"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make BINDIR=/sbin install" ${_logfile}
	cat > /etc/syslog.conf <<- "EOF"
		# Begin /etc/syslog.conf

		auth,authpriv.* -/var/log/auth.log
		*.*;auth,authpriv.none -/var/log/sys.log
		daemon.* -/var/log/daemon.log
		kern.* -/var/log/kern.log
		mail.* -/var/log/mail.log
		user.* -/var/log/user.log
		*.emerg *

		# End /etc/syslog.conf
	EOF
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-57() {
	local	_pkgname="sysvinit"
	local	_pkgver="2.88dsf"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Patch" "patch -Np1 -i ../../SOURCES/sysvinit-2.88dsf-consolidated-1.patch" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS} -C src" ${_logfile}
	build "Install" "make -C src install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-58() {
	local	_pkgname="tar"
	local	_pkgver="1.27.1"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Patch" "patch -Np1 -i ../../SOURCES/tar-1.27.1-manpage-1.patch" ${_logfile}
	build "Configure" "FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr --bindir=/bin" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "make -C doc install-html docdir=/usr/share/doc/${_pkgname}-${_pkgver}" "make -C doc install-html docdir=/usr/share/doc/${_pkgname}-${_pkgver}" ${_logfile}
	build "perl tarman > /usr/share/man/man1/tar.1" "perl tarman > /usr/share/man/man1/tar.1" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-59() {
	local	_pkgname="texinfo"
	local	_pkgver="5.2"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr " ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "make TEXMF=/usr/share/texmf install-tex" "make TEXMF=/usr/share/texmf install-tex" ${_logfile}
	build "Change directory: /usr/share/info" "pushd /usr/share/info" ${_logfile}
	build "rm -v dir" "rm -v dir" ${_logfile}
	build 'for f in * for f in *;do install-info $f dir 2>/dev/null;done;' 'for f in * for f in *;do install-info $f dir 2>/dev/null;done;' ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-60() {
	local	_pkgname="systemd"
	local	_pkgver="208"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	unpack "${PWD}" "udev-lfs-208-3"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "ln -vs ../udev-lfs-208-3" "ln -vs ../udev-lfs-208-3" ${_logfile}
	build "ln -svf /tools/include/blkid /usr/include" "ln -svf /tools/include/blkid /usr/include" ${_logfile}
	build "ln -svf /tools/include/uuid  /usr/include" "ln -svf /tools/include/uuid  /usr/include" ${_logfile}
	export LD_LIBRARY_PATH=/tools/lib
	build "Make" "make V=1 ${MKFLAGS} -f udev-lfs-208-3/Makefile.lfs" ${_logfile}
	build "Install" "make -f udev-lfs-208-3/Makefile.lfs install" ${_logfile}
	build "build/udevadm hwdb --update" "build/udevadm hwdb --update" ${_logfile}
	build "bash udev-lfs-208-3/init-net-rules.sh" "bash udev-lfs-208-3/init-net-rules.sh" ${_logfile}
	build "rm -fv /usr/include/{uuid,blkid}" "rm -fv /usr/include/{uuid,blkid}" ${_logfile}
	unset LD_LIBRARY_PATH
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-61() {
	local	_pkgname="util-linux"
	local	_pkgver="2.24.1"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "sed -i -e 's@etc/adjtime@var/lib/hwclock/adjtime@g' \$(grep -rl '/etc/adjtime' .)" "sed -i -e 's@etc/adjtime@var/lib/hwclock/adjtime@g' $(grep -rl '/etc/adjtime' .)" ${_logfile}
	build "mkdir -pv /var/lib/hwclock" "mkdir -pv /var/lib/hwclock" ${_logfile}
	build "Configure" "./configure --prefix=/usr " ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-62() {
	local	_pkgname="man-db"
	local	_pkgver="2.6.6"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Configure" "./configure --prefix=/usr --docdir=/usr/share/doc/${_pkgname}-${_pkgver} --sysconfdir=/etc --disable-setuid --with-browser=/usr/bin/lynx --with-vgrind=/usr/bin/vgrind --with-grap=/usr/bin/grap" ${_logfile}
	build "Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-63() {
	local	_pkgname="vim"
	local	_pkgver="7.4"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}74" "pushd ${_pkgname}74" ${_logfile}
	build 	'echo #define SYS_VIMRC_FILE "/etc/vimrc" >> src/feature.h' 'printf "%s\n" "#define SYS_VIMRC_FILE \"/etc/vimrc\" " >> src/feature.h' ${_logfile}
	build	"Configure" "./configure --prefix=/usr --enable-multibyte" ${_logfile}
	build	"Make" "make V=1 ${MKFLAGS}" ${_logfile}
	build	"Install" "make install" ${_logfile}
	build	"ln -sv vim /usr/bin/vi" "ln -sv vim /usr/bin/vi" ${_logfile}
	build	'for L in  /usr/share/man/{,*/}man1/vim.1; do ln -sv vim.1 $(dirname $L)/vi.1;done;' 'for L in  /usr/share/man/{,*/}man1/vim.1; do ln -sv vim.1 $(dirname $L)/vi.1;done;' ${_logfile}
	build	"ln -sv ../vim/vim74/doc /usr/share/doc/${_pkgname}-${_pkgver}" "ln -sv ../vim/vim74/doc /usr/share/doc/${_pkgname}-${_pkgver}" ${_logfile}
	cat > /etc/vimrc <<- "EOF"
		" Begin /etc/vimrc

		set nocompatible
		set backspace=2
		syntax on
		if (&term == "iterm") || (&term == "putty")
			set background=dark
		endif

		" End /etc/vimrc
	EOF
	build "Restore directory" "popd " /dev/null
	build "Restore directory" "popd " /dev/null
	>  ${_complete}
	return 0
}
chapter-6-65() {
	#	strip libs and executables upon building
	return 0
	local	_complete="${LOGDIR}/${FUNCNAME}.completed"
	local	_logfile="${LOGDIR}/${FUNCNAME}.log"
	local	_checkfile="${LOGDIR}/${FUNCNAME}.check"
	local	_pkgname=""
	local	_pkgver=""
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build	"/tools/bin/find /{,usr/}{bin,lib,sbin} -type f -exec /tools/bin/strip --strip-debug '{}' ';'" \
		"/tools/bin/find /{,usr/}{bin,lib,sbin} -type f -exec /tools/bin/strip --strip-debug '{}' ';'" \
		${_logfile}
	>  ${_complete}
	return 0
}
chapter-7-00() {
	local	_pkgname="lfs-bootscripts"
	local	_pkgver="20130821"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "Install" "make install" ${_logfile}
	build "Restore directory" "popd " /dev/null		
	msg "	7.2.2. Creating Network Interface Configuration Files"
	cat > /etc/sysconfig/ifconfig.eth0 <<- "EOF"
		ONBOOT=yes
		IFACE=eth0
		SERVICE=ipv4-static
		IP=<192.168.1.1>
		GATEWAY=<192.168.1.1>
		PREFIX=24
		BROADCAST=<255.255.255.0>
	EOF
	msg "	7.2.3. Creating the /etc/resolv.conf File"
	cat > /etc/resolv.conf <<- "EOF"
		# Begin /etc/resolv.conf

		domain <Domain Name>
		nameserver <IP primary nameserver>
		nameserver <IP secondary nameserver>

		# End /etc/resolv.conf
	EOF
	msg "	7.3. Customizing the /etc/hosts File"
	cat > /etc/hosts <<- "EOF"
		# Begin /etc/hosts (network card version)

		127.0.0.1 localhost
		<192.168.1.1> <HOSTNAME.example.org> [alias1] [alias2 ...]

		# End /etc/hosts (network card version)
	EOF
	msg "	7.7.1. Configuring Sysvinit"
	cat > /etc/inittab <<- "EOF"
		# Begin /etc/inittab
		id:3:initdefault:

		si::sysinit:/etc/rc.d/init.d/rc S

		l0:0:wait:/etc/rc.d/init.d/rc 0
		l1:S1:wait:/etc/rc.d/init.d/rc 1
		l2:2:wait:/etc/rc.d/init.d/rc 2
		l3:3:wait:/etc/rc.d/init.d/rc 3
		l4:4:wait:/etc/rc.d/init.d/rc 4
		l5:5:wait:/etc/rc.d/init.d/rc 5
		l6:6:wait:/etc/rc.d/init.d/rc 6

		ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now

		su:S016:once:/sbin/sulogin

		1:2345:respawn:/sbin/agetty --noclear tty1 9600
		2:2345:respawn:/sbin/agetty tty2 9600
		3:2345:respawn:/sbin/agetty tty3 9600
		4:2345:respawn:/sbin/agetty tty4 9600
		5:2345:respawn:/sbin/agetty tty5 9600
		6:2345:respawn:/sbin/agetty tty6 9600

		# End /etc/inittab
	EOF
	msg "	7.8. Configuring the system hostname"
	build 'echo "HOSTNAME=<lfs>" > /etc/sysconfig/network' 'echo "HOSTNAME=<lfs>" > /etc/sysconfig/network' ${_logfile}
	msg "	7.9. Configuring the setclock Script"
	cat > /etc/sysconfig/clock <<- "EOF"
		# Begin /etc/sysconfig/clock

		UTC=1

		# Set this to any options you might need to give to hwclock,
		# such as machine hardware clock type for Alphas.
		CLOCKPARAMS=

		# End /etc/sysconfig/clock
	EOF
	msg "	7.10. Configuring the Linux Console"
	cat > /etc/sysconfig/console <<- "EOF"
		# Begin /etc/sysconfig/console

		#	UNICODE="1"
		#	KEYMAP="bg_bds-utf8"
		#	FONT="cyr-sun16"

		# End /etc/sysconfig/console
	EOF
	msg "	7.13. The Bash Shell Startup Files"
	cat > /etc/profile <<- "EOF"
		# Begin /etc/profile

		#	export LANG=<ll>_<CC>.<charmap><@modifiers>

		# End /etc/profile
	EOF
	msg "	7.14. Creating the /etc/inputrc File"
	cat > /etc/inputrc <<- "EOF"
		# Begin /etc/inputrc
		# Modified by Chris Lynn <roryo@roryo.dynup.net>

		# Allow the command prompt to wrap to the next line
		set horizontal-scroll-mode Off

		# Enable 8bit input
		set meta-flag On
		set input-meta On

		# Turns off 8th bit stripping
		set convert-meta Off

		# Keep the 8th bit for display
		set output-meta On

		# none, visible or audible
		set bell-style none

		# All of the following map the escape sequence of the value
		# contained in the 1st argument to the readline specific functions
		"\eOd": backward-word
		"\eOc": forward-word

		# for linux console
		"\e[1~": beginning-of-line
		"\e[4~": end-of-line
		"\e[5~": beginning-of-history
		"\e[6~": end-of-history
		"\e[3~": delete-char
		"\e[2~": quoted-insert

		# for xterm
		"\eOH": beginning-of-line
		"\eOF": end-of-line

		# for Konsole
		"\e[H": beginning-of-line
		"\e[F": end-of-line

		# End /etc/inputrc
	EOF
	build "Restore directory" "popd " ${_logfile}
	>  ${_complete}
	return 0
}
chapter-8-00() {
	local	_pkgname="linux"
	local	_pkgver="3.13.3"
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	build "Change directory: BUILD" "pushd BUILD" ${_logfile}
	unpack "${PWD}" "${_pkgname}-${_pkgver}"
	build "Change directory: ${_pkgname}-${_pkgver}" "pushd ${_pkgname}-${_pkgver}" ${_logfile}
	build "make mrproper" "make mrproper" ${_logfile}
	build "cp ../../config .config" "cp ../../config .config" ${_logfile}
	build "make LC=ALL= oldconfig" "make LC=ALL= oldconfig" ${_logfile}
	build "make " "make V=1  ${MKFLAGS}" ${_logfile}
	build "make modules_install" "make modules_install" ${_logfile}
	build "cp -v arch/x86/boot/bzImage /boot/vmlinuz-${_pkgver}-lfs-7.5" "cp -v arch/x86/boot/bzImage /boot/vmlinuz-${_pkgver}-lfs-7.5" ${_logfile}
	build "cp -v System.map /boot/System.map-${_pkgver}" "cp -v System.map /boot/System.map-${_pkgver}" ${_logfile}
	build "cp -v .config /boot/config-${_pkgver}" "cp -v .config /boot/config-${_pkgver}" ${_logfile}
	build "install -d /usr/share/doc/${_pkgname}-${_pkgver}" "install -d /usr/share/doc/${_pkgname}-${_pkgver}" ${_logfile}
	build "cp -r Documentation/* /usr/share/doc/${_pkgname}-${_pkgver}" "cp -r Documentation/* /usr/share/doc/${_pkgname}-${_pkgver}" ${_logfile}
	build "install -v -m755 -d /etc/modprobe.d" "install -v -m755 -d /etc/modprobe.d" ${_logfile}
	build "Restore directory" "popd " ${_logfile}
	build "Restore directory" "popd " ${_logfile}
	msg "       Chapter 8. Making the LFS System Bootable"
	cat > /etc/fstab <<- "EOF"
		# Begin /etc/fstab

		# file system  mount-point  type     options             dump  fsck
		#                                                              order

		/dev/<sdxx>    /            <fff>    defaults            1     1
		/dev/<sdxx>    swap         swap     pri=1               0     0
		proc           /proc        proc     nosuid,noexec,nodev 0     0
		sysfs          /sys         sysfs    nosuid,noexec,nodev 0     0
		devpts         /dev/pts     devpts   gid=5,mode=620      0     0
		tmpfs          /run         tmpfs    defaults            0     0
		devtmpfs       /dev         devtmpfs mode=0755,nosuid    0     0
		#tmpfs         /tmp         tmpfs    defaults            0     0

		# End /etc/fstab
	EOF
	cat > /etc/modprobe.d/usb.conf <<- "EOF"
		# Begin /etc/modprobe.d/usb.conf

		install ohci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i ohci_hcd ; true
		install uhci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i uhci_hcd ; true

		# End /etc/modprobe.d/usb.conf
	EOF
#	msg "	8.4. Using GRUB to Set Up the Boot Process"
#	cd /tmp &&
#	grub-mkrescue --output=grub-img.iso &&
#	xorriso -as cdrecord -v dev=/dev/cdrw blank=as_needed grub-img.iso
#	grub-install /dev/sda
#	build "install -vdm 755 /boot/grub" "install -vdm 755 /boot/grub" ${_logfile}
#	cat > /boot/grub/grub.cfg <<- "EOF"
#		# Begin /boot/grub/grub.cfg
#		set default=0
#		set timeout=5
#
#		insmod ext2
#		set root=(hd0,2)
#
#		menuentry "GNU/Linux, Linux 3.13.3-lfs-7.5" {
#			linux   /boot/vmlinuz-3.13.3-lfs-7.5 root=/dev/sda2 ro
#		}
#	EOF
>  ${_complete}
	return 0
}
chapter-9-00() {
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
	build "Clean build directory" 'rm -rf BUILD/*' ${_logfile}
	msg "	9.1. The End"
	build "echo 7.5 > /etc/lfs-release" "echo 7.5 > /etc/lfs-release" ${_logfile}
	cat > /etc/lsb-release <<- "EOF"
		DISTRIB_ID="Linux From Scratch"
		DISTRIB_RELEASE="7.5"
		DISTRIB_CODENAME="Octothorpe"
		DISTRIB_DESCRIPTION="Linux From Scratch"
	EOF
	>  ${_complete}
	return 0
}
chapter-config(){
	local	_logfile="${PARENT}/LOGS/${FUNCNAME}.log"
	local	_complete="${PARENT}/LOGS/${FUNCNAME}.completed"
	local _list="/etc/sysconfig/clock "
	_list+="/etc/sysconfig/console "
	_list+="/etc/profile "
	_list+="/etc/sysconfig/network "
	_list+="/etc/hosts "
	_list+="/etc/fstab "
	_list+="/etc/sysconfig/ifconfig.eth0 "
	_list+="/etc/resolv.conf "
	_list+="/etc/passwd "
	_list+="/etc/lsb-release "
	_list+="/etc/sysconfig/rc.site"
	[ -e ${_complete} ] && { msg "${FUNCNAME}: SKIPPING";return 0; } || msg "${FUNCNAME}: Building"
	> ${_logfile}
#	build '/sbin/locale-gen.sh' '/sbin/locale-gen.sh' ${_logfile}
	build '/sbin/ldconfig' '/sbin/ldconfig' ${_logfile}
	#	enable shadowed passwords and group passwords
	build '/usr/sbin/pwconv' '/usr/sbin/pwconv' ${_logfile}
	build '/usr/sbin/grpconv' '/usr/sbin/grpconv' ${_logfile}
	build '/sbin/udevadm hwdb --update' '/sbin/udevadm hwdb --update' ${_logfile}
	#	Configuration
	for i in ${_list}; do vim "${i}";done
	>  ${_complete}
	return 0
}
#
#	Command line Functions
#
cmd_mount() {
	local i=""
	[ ${EUID} -eq 0 ] || die "${FUNCNAME}: Need to be root user: FAILURE"
	[ -d ${LFS} ] || install -dm 755 ${LFS} || die "${FUNCNAME}: FAILURE"
	chmod 755 ${LFS} || die "${FUNCNAME}: FAILURE"
	for ((i=0;i<${#MNT_POINT[@]};++i)); do
		[ "sdxx" = "${PARTITION[i]}" ] && continue
		mountpoint /mnt/${MNT_POINT[i]} > /dev/null 2>&1 && continue
		msg_line "Mounting: ${PARTITION[i]} --> ${MNT_POINT[i]}: "
		install -dm 755 /mnt/${MNT_POINT[i]} || die "${FUNCNAME}: FAILURE"
		mount -t ${FILSYSTEM[i]} /dev/${PARTITION[i]} /mnt/${MNT_POINT[i]} || die "${FUNCNAME}: FAILURE"
		msg_success
	done
	[ -d ${LFS}/tools ]	|| { install -dm 775 ${LFS}/tools || die "${FUNCNAME}: FAILURE"; }
	[ -h /tools ]		|| { ln -s ${LFS}/tools /         || die "${FUNCNAME}: FAILURE"; }
	return 0
}
cmd_umount() {
	[ ${EUID} -eq 0 ] || die "${FUNCNAME}: Need to be root user: FAILURE"
	msg_line "Unmounting ${LFS} partitions: "
	umount -v -R ${LFS} > /dev/null 2>&1 || die "${FUNCNAME}: FAILURE"
	rm -rf ${LFS} || die "${FUNCNAME}: FAILURE"
	rm -rf /tools || die "${FUNCNAME}: FAILURE"
	msg_success
	return 0
}
cmd_filesystem() {
	local i=""
	local p=""
	[ ${EUID} -eq 0 ] || die "${FUNCNAME}: Need to be root user: FAILURE"
	msg "Create/wipe filesystem(s)"
	for ((i=0;i<${#MNT_POINT[@]};++i)); do
		[ "sdxx" = "${PARTITION[i]}" ] && continue
		msg_line "       Create/wipe filesystem on /dev/${PARTITION[i]} (y/n) "
		read p
		case $p in
			y|Y)	true ;;
			n|N)	die "       Canceling create filesystem, Can not continue" ;;
			*)	die "       Invalid response, Can not continue" ;;
		esac
		msg_line "Creating filesystem: ${PARTITION[i]} on ${MNT_POINT[i]}: "
		mkfs -v -t ${FILSYSTEM[i]} /dev/${PARTITION[i]} > /dev/null 2>&1 || die "${FUNCNAME}: FAILURE"
		msg_success
	done
	return 0
}
cmd_fetch() {
	msg_line "Fetching source packages: "
	[ -d SOURCES ] || install -dm755 SOURCES
	wget -nc -i wget-list -P SOURCES > /dev/null 2>&1 || die "${FUNCNAME}: FAILURE"
	pushd SOURCES > /dev/null 2>&1;
		md5sum -c ../md5sums > /dev/null 2>&1 || die "Check of source packages FAILED"
	popd > /dev/null 2>&1;
	msg_success
	return 0
}
cmd_install() {
	local p=""
	msg "Install build system"
	[ ${EUID} -eq 0 ] || die "${FUNCNAME}: Need to be root user: FAILURE"
	mountpoint ${LFS} > /dev/null 2>&1 || {
		msg_line "       /mnt/lfs is not mounted: continue: (y/n) "
		read p
		case $p in
			y|Y)	msg "       Installing build system to directory"; true ;;
			n|N)	die "       Canceling, Can not continue" ;;
			*)	die "       Invalid response, Can not continue" ;;
		esac
	}
	msg_line "       Installing build system to ${LFS}${PARENT}: "
#	mountpoint ${LFS} > /dev/null 2>&1 || die "${FUNCNAME}: ${LFS} is not mounted"
	install -dm 755 ${LFS}/${PARENT}/{BOOK,BUILD,LOGS,SOURCES} || die "${FUNCNAME}: Can not create directories"
	cp -ar BOOK SOURCES builder md5sums wget-list config* version-check "${LFS}/${PARENT}" || die "${FUNCNAME}: Error trying to copy build system to ${LFS}/${PARENT}"
	chmod 775 ${LFS}/${PARENT}/builder
	unmount_filesystems && chown -R lfs:lfs ${LFS} || die "${FUNCNAME}: FAILURE"
	msg_success
	return 0
}
cmd_rmuser() {
	[ ${EUID} -eq 0 ] || die "${FUNCNAME}: Need to be root user: FAILURE"
	msg_line "Removing lfs user: "
	getent passwd lfs > /dev/null 2>&1 && { userdel  lfs || die "Can not remove lfs user "; }
	getent group  lfs > /dev/null 2>&1 && { groupdel lfs || die "Can not remove lfs group"; }
	[ -d "/home/lfs" ] && { rm -rf "/home/lfs" || die "${FUNCNAME}: FAILURE"; }
	msg_success
	return 0
}
cmd_user() {
	[ ${EUID} -eq 0 ] || die "${FUNCNAME}: Need to be root user: FAILURE"
	msg_line "Creating lfs user: "
	getent group  lfs > /dev/null 2>&1 || { groupadd lfs || die "Can not create lfs group"; }
	getent passwd lfs > /dev/null 2>&1 || { useradd -c 'LFS user' -g lfs -m -k /dev/null -s /bin/bash lfs || die "Can not create lfs user"; }
	passwd -l lfs > /dev/null 2>&1  || die "${FUNCNAME}: FAILURE"
	cat > /home/lfs/.bash_profile <<- EOF
		exec env -i HOME=/home/lfs TERM=${TERM} PS1='\u:\w\$ ' /bin/bash
	EOF
	cat > /home/lfs/.bashrc <<- EOF
		set +h
		umask 022
		LFS=/mnt/lfs
		LC_ALL=POSIX
		LFS_TGT=$(uname -m)-lfs-linux-gnu
		PATH=/tools/bin:/bin:/usr/bin
		export LFS LC_ALL LFS_TGT PATH
	EOF
	chown -R lfs:lfs /home/lfs	|| die "${FUNCNAME}: FAILURE"
	msg_success
	return 0
}
cmd_tools() {
	[ "lfs" != $(whoami) ] && die "${FUNCNAME}: Not lfs user: FAILURE"
	msg "Building Chapter 5 Tool chain"
	cd ${LFS}${PARENT}
		chapter-5-04	#	5.4. Binutils-2.24 - Pass 1
		chapter-5-05	#	5.5. GCC-4.8.2 - Pass 1
		chapter-5-06	#	5.6. Linux-3.13.3 API Headers
		chapter-5-07	#	5.7. Glibc-2.19
		chapter-5-08	#	5.8. Libstdc++-4.8.2
		chapter-5-09	#	5.9. Binutils-2.24 - Pass 2
		chapter-5-10	#	5.10. GCC-4.8.2 - Pass 2
		chapter-5-11	#	5.11. Tcl-8.6.1
		chapter-5-12	#	5.12. Expect-5.45
		chapter-5-13	#	5.13. DejaGNU-1.5.1
		chapter-5-14	#	5.14. Check-0.9.12
		chapter-5-15	#	5.15. Ncurses-5.9
		chapter-5-16	#	5.16. Bash-4.2
		chapter-5-17	#	5.17. Bzip2-1.0.6
		chapter-5-18	#	5.18. Coreutils-8.22
		chapter-5-19	#	5.19. Diffutils-3.3
		chapter-5-20	#	5.20. File-5.17
		chapter-5-21	#	5.21. Findutils-4.4.2
		chapter-5-22	#	5.22. Gawk-4.1.0
		chapter-5-23	#	5.23. Gettext-0.18.3.2
		chapter-5-24	#	5.24. Grep-2.16
		chapter-5-25	#	5.25. Gzip-1.6
		chapter-5-26	#	5.26. M4-1.4.17
		chapter-5-27	#	5.27. Make-4.0
		chapter-5-28	#	5.28. Patch-2.7.1
		chapter-5-29	#	5.29. Perl-5.18.2
		chapter-5-30	#	5.30. Sed-4.2.2 
		chapter-5-31	#	5.31. Tar-1.27.1
		chapter-5-32	#	5.32. Texinfo-5.2
		chapter-5-33	#	5.33. Util-linux-2.24.1
		chapter-5-34	#	5.34. Xz-5.0.5
#		The following are not used
#		chapter-5-35	#	5.35. Stripping
#		chapter-5-36	#	5.36. Changing Ownership
	return 0
}
cmd_system() {
	[ ${EUID} -eq 0 ] || die "${FUNCNAME}: Need to be root user: FAILURE"
	if [ -d /mnt/lfs/tools ]; then 	#	We are not in chroot so set this up
		# the line below umount the kernel filesystems so we can change ownership
		unmount_filesystems && chown -R 0:0 /mnt/lfs/* || die "${FUNCNAME}: FAILURE"
		cd ${LFS}${PARENT}
		chapter-6-02 		#	Create chroot environment
		mount_filesystems	#	Mount kernel fileystems
		chroot "${LFS}" \
			/tools/bin/env -i \
			HOME=/root \
			TERM="$TERM" \
			PS1='\u:\w\$ ' \
			PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
			/tools/bin/bash --login +h -c "/usr/src/Octothorpe/builder -s"
		unmount_filesystems
	else
		cd /usr/src/Octothorpe
		chapter-6-05	# Creating Directories
		chapter-6-06	# Creating Essential Files and Symlinks
		chapter-6-07	# Linux-3.13.3 API Headers
		chapter-6-08	# Man-pages-3.59
		chapter-6-09.0	# Glibc-2.19
		chapter-6-09.1	# Timezone data
		chapter-6-10	# Adjusting the Toolchain
		chapter-6-11	# Zlib-1.2.8
		chapter-6-12	# File-5.17
		chapter-6-13	# Binutils-2.24
		chapter-6-14	# GMP-5.1.3
		chapter-6-15	# MPFR-3.1.2
		chapter-6-16	# MPC-1.0.2
		chapter-6-17	# GCC-4.8.2
		chapter-6-18	# Sed-4.2.2
		chapter-6-19	# Bzip2-1.0.6
		chapter-6-20	# Pkg-config-0.28
		chapter-6-21	# Ncurses-5.9
		chapter-6-22	# Shadow-4.1.5.1
		chapter-6-23	# Psmisc-22.20
		chapter-6-24	# Procps-ng-3.3.9
		chapter-6-25	# E2fsprogs-1.42.9
		chapter-6-26	# Coreutils-8.22
		chapter-6-27	# Iana-Etc-2.30
		chapter-6-28	# M4-1.4.17
		chapter-6-29	# Flex-2.5.38
		chapter-6-30	# Bison-3.0.2
		chapter-6-31	# Grep-2.16
		chapter-6-32	# Readline-6.2
		chapter-6-33	# Bash-4.2
		chapter-6-34	# Bc-1.06.95
		chapter-6-35	# Libtool-2.4.2
		chapter-6-36	# GDBM-1.11
		chapter-6-37	# Inetutils-1.9.2
		chapter-6-38	# Perl-5.18.2
		chapter-6-39	# Autoconf-2.69
		chapter-6-40	# Automake-1.14.1
		chapter-6-41	# Diffutils-3.3
		chapter-6-42	# Gawk-4.1.0
		chapter-6-43	# Findutils-4.4.2
		chapter-6-44	# Gettext-0.18.3.2
		chapter-6-45	# Groff-1.22.2
		chapter-6-46	# Xz-5.0.5
		chapter-6-47	# GRUB-2.00
		chapter-6-48	# Less-458
		chapter-6-49	# Gzip-1.6
		chapter-6-50	# IPRoute2-3.12.0
		chapter-6-51	# Kbd-2.0.1
		chapter-6-52	# Kmod-16
		chapter-6-53	# Libpipeline-1.2.6
		chapter-6-54	# Make-4.0
		chapter-6-55	# Patch-2.7.1
		chapter-6-56	# Sysklogd-1.5
		chapter-6-57	# Sysvinit-2.88dsf
		chapter-6-58	# Tar-1.27.1
		chapter-6-59	# Texinfo-5.2
		chapter-6-60	# Udev-208 (Extracted from systemd-208)
		chapter-6-61	# Util-linux-2.24.1
		chapter-6-62	# Man-DB-2.6.6
		chapter-6-63	# Vim-7.4
		chapter-6-65	# Stripping
		chapter-7-00	# 
		chapter-8-00	# 
		chapter-9-00	# 
		chapter-config	# Configure system	
	fi
	return 0
}
#
#	Main line
#
MK_UMOUNT=false
MK_MOUNT=false
MK_FILESYSTEM=false
MK_MOUNT=false
MK_FETCH=false
MK_INSTALL=false
MK_USER=false
MK_RMUSER=false
MK_TOOLS=false
MK_SYSTEM=false
OPTSTRING=cmufirltsh
[ $# -eq 0 ] && usage
while getopts $OPTSTRING opt; do
	case $opt in
		u)	MK_UMOUNT=true		;;
		m)	MK_MOUNT=true 		;;
		c)	MK_FILESYSTEM=true	;;
		f)	MK_FETCH=true		;;
		i)	MK_INSTALL=true		;;
		r)	MK_RMUSER=true		;;
		l)	MK_USER=true		;;
		s)	MK_SYSTEM=true		;;
		t)	MK_TOOLS=true		;;
		h)	usage			;;
		*)	usage			;;
	esac
done
shift $(( $OPTIND - 1 ))	# remove options from command line
[ ${MK_RMUSER} = "true" ]	&& cmd_rmuser
[ ${MK_UMOUNT} = "true" ] 	&& cmd_umount
[ ${MK_FILESYSTEM} = "true" ]	&& cmd_filesystem
[ ${MK_MOUNT} = "true" ]	&& cmd_mount
[ ${MK_USER} = "true" ]		&& cmd_user
[ ${MK_FETCH} = "true" ]	&& cmd_fetch
[ ${MK_INSTALL} = "true" ]	&& cmd_install
[ ${MK_TOOLS} = "true" ]	&& cmd_tools
[ ${MK_SYSTEM} = "true" ]	&& cmd_system
#msg "Run Completed"
