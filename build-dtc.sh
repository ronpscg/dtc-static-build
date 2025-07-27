#
# An example of how to create dtc statically for different architectures
#
# Used to accompany The PSCG's training/Ron Munitz's talks
#
# Notes: 
# 1. dtc in the kernel requires the kernel build system. this is external.
# 2. the project used to use GNU make which would be simpler
# 3. This project uses the meson build system and ninja
#
# I will not write much more about it, and I will not bother with the install targets etc.
#
: ${SRC_PROJECT=$(readlink -f ./dtc)}
: ${USE_MULTILIB_FOR_32BIT_X86=false}	# if true - use -m32. This conflicts with all cross-compilers. A better alternative for 2025 is to use native toolchain distro, i686-linux-gnu-...

declare -A ARCHS
ARCHS[x86_64-linux-gnu]=x86_64
ARCHS[aarch64-linux-gnu]=arm64
ARCHS[riscv64-linux-gnu]=riscv
ARCHS[arm-linux-gnueabi]=arm
ARCHS[arm-linux-gnueabihf]=arm
ARCHS[i686-linux-gnu]=i386
ARCHS[loongarch64-linux-gnu]=longarch

: ${MORE_CONFIGURE_FLAGS=""}
: ${MORE_TUPPLES=""}



# Copying some things from PscgBuildOS to save time. This busybox external project is just nice to have and I make it to store prebuilts in an easily accessible way,
# as I do not use prebuilts neither in PSCG-mini-linux nor in PscgBuildOS
warn() { echo -e "\x1b[33m$@\x1b[0m" ; }
fatalError() { echo -e "\x1b[41m$@\x1b[0m" ; exit 1 ; }


#
# Common configuration. Could create configuration files, preferred to do it in place so there is one file to edit upon changes
# 
# $1 src dir
# $2 build dir
# $3 install dir
#
configure_defaults() (
	srcdir=$1
	builddir=$2
	installdir=$3

	cd $SRC_PROJECT

	meson setup $builddir --cross-file <(cat <<EOF
[binaries]
c = '${CROSS_COMPILE}gcc'
ar = '${CROSS_COMPILE}ar'
strip = '${CROSS_COMPILE}strip'
pkg-config = 'false'

# One could be fine without a [host-machine]

[project options]
c_link_args = ['-static']
EOF

) --default-library static -Dtests=false --prefix=$installdir --wipe
)

#
# $1: build directory
# $2: install directory
#
build_with_installing() (
	set -euo pipefail # will only apply to this subshell. Prints were added - if nothing is being done - it might be because the folder exists and you will see it in the arch logs
	builddir=$(readlink -f $1)
	installdir=$(readlink -f $2)
	#mkdir $1 # You must create the build and install directories. make will not do that for you
	#cd $1

	echo -e "\x1b[34mConfiguring $tuple\x1b[0m"
	configure_defaults $SRC_PROJECT $(readlink -f $1) $installdir


	echo -e "\x1b[34mBuilding and installing $tuple\x1b[0m ($PWD)"
	ninja -C $builddir install
	echo -e "\x1b[34mStripping $tuple\x1b[0m ($PWD)" || { echo -e "\x1b[31mFailed to strip for $installdir\x1b[0m" ; exit 1 ; }
	find $installdir -executable -not -type d | xargs ${CROSS_COMPILE}strip -s
	echo -e "\x1b[32m$tuple - Done!\x1b[0m ($PWD)"
)


# This example builds for several tuples
# The function above can be used from outside a script, assuming that the CROSS_COMPILE variable is set
# It may however need more configuration if you do not build for gnulibc
build_for_several_tuples() {
	local failing_tuples=""
	for tuple in x86_64-linux-gnu aarch64-linux-gnu riscv64-linux-gnu arm-linux-gnueabi arm-linux-gnueabihf i686-linux-gnu loongarch64-linux-gnu $MORE_TUPPLES ; do
	#for tuple in $MORE_TUPPLES aarch64-linux-gnu ; do
		echo -e "\x1b[35mConfiguring and building $tuple\x1b[0m"
		export CROSS_COMPILE=${tuple}- # we'll later strip it but CROSS_COMPILE is super standard, and autotools is "a little less standard"
		export ARCH=${ARCHS[$tuple]}
		build_with_installing $tuple-build $tuple-install 2> err.$tuple || failing_tuples="$failing_tuples $tuple"
	done

	if [ -z "$failing_tuples" ] ; then
		echo -e "\x1b[32mDone\x1b[0m"
	else
		echo "\x1b[33mDone\x1b[0m You can see errors in $(for x in $failing_tuples ; do echo err.$x ; done)"
	fi
}

fetch() (
	# the last time this was updated, master was at commit e0b7749c26a9ea28a480bca4a87d238e284ac68f (sometime after v1.7.2)
	# it is not explicitly mentioned, because it could be rebased
	: ${CHECKOUT_COMMIT=""} #

	git clone https://github.com/dgibson/dtc.git

)

main() {
	fetch || exit 1
	build_for_several_tuples
}

main $@
