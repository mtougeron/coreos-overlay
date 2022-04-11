# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="7"
WANT_LIBTOOL="none"

inherit autotools check-reqs flag-o-matic multiprocessing \
	python-utils-r1 toolchain-funcs verify-sig

MY_PV=${PV/_rc/rc}
MY_P="Python-${MY_PV%_p*}"
PYVER=$(ver_cut 1-2)
PATCHSET="python-gentoo-patches-${MY_PV}"

DESCRIPTION="An interpreted, interactive, object-oriented programming language"
HOMEPAGE="https://www.python.org/"
SRC_URI="https://www.python.org/ftp/python/${PV%_*}/${MY_P}.tar.xz
	https://dev.gentoo.org/~mgorny/dist/python/${PATCHSET}.tar.xz
	verify-sig? (
		https://www.python.org/ftp/python/${PV%_*}/${MY_P}.tar.xz.asc
	)"
S="${WORKDIR}/${MY_P}"

LICENSE="PSF-2"
SLOT="${PYVER}"
KEYWORDS="~alpha amd64 arm arm64 hppa ~ia64 ~m68k ~mips ppc ppc64 ~riscv ~s390 sparc x86"
IUSE="hardened"

# Do not add a dependency on dev-lang/python to this ebuild.
# If you need to apply a patch which requires python for bootstrapping, please
# run the bootstrap code on your dev box and include the results in the
# patchset. See bug 447752.

DEPEND="app-arch/bzip2:=
	app-arch/xz-utils:=
	dev-lang/python-exec[python_targets_python3_9(-)]
	sys-apps/util-linux:=
	>=sys-libs/zlib-1.1.3:=
	virtual/libcrypt:=
	virtual/libintl"
BDEPEND="
	virtual/awk
	virtual/pkgconfig
	sys-devel/autoconf-archive
	verify-sig? ( sec-keys/openpgp-keys-python )
	!sys-devel/gcc[libffi(-)]"

VERIFY_SIG_OPENPGP_KEY_PATH=${BROOT}/usr/share/openpgp-keys/python.org.asc

# large file tests involve a 2.5G file being copied (duplicated)
CHECKREQS_DISK_BUILD=5500M

src_unpack() {
	if use verify-sig; then
		verify-sig_verify_detached "${DISTDIR}"/${MY_P}.tar.xz{,.asc}
	fi
	default
}

src_prepare() {
	# Ensure that internal copies of zlib are not used.
	rm -fr Modules/zlib || die

	local PATCHES=(
		"${WORKDIR}/${PATCHSET}"
	)

	default

	sed -i -e "s:@@GENTOO_LIBDIR@@:$(get_libdir):g" \
		setup.py || die "sed failed to replace @@GENTOO_LIBDIR@@"

	# force correct number of jobs
	# https://bugs.gentoo.org/737660
	local jobs=$(makeopts_jobs "${MAKEOPTS}" "$(get_nproc)")
	sed -i -e "s:-j0:-j${jobs}:" Makefile.pre.in || die
	sed -i -e "/self\.parallel/s:True:${jobs}:" setup.py || die

	eautoreconf
}

src_configure() {
	local disable
	# disable automagic bluetooth headers detection
	export ac_cv_header_bluetooth_bluetooth_h=no
	disable+=" gdbm"
	disable+=" _curses _curses_panel"
	disable+=" readline"
	disable+=" _sqlite3"
	export PYTHON_DISABLE_SSL="1"
	disable+=" _tkinter"
	export PYTHON_DISABLE_MODULES="${disable}"

	if [[ -n "${PYTHON_DISABLE_MODULES}" ]]; then
		einfo "Disabled modules: ${PYTHON_DISABLE_MODULES}"
	fi

	if [[ "$(gcc-major-version)" -ge 4 ]]; then
		append-flags -fwrapv
	fi

	filter-flags -malign-double

	# https://bugs.gentoo.org/show_bug.cgi?id=50309
	if is-flagq -O3; then
		is-flagq -fstack-protector-all && replace-flags -O3 -O2
		use hardened && replace-flags -O3 -O2
	fi

	# https://bugs.gentoo.org/700012
	if is-flagq -flto || is-flagq '-flto=*'; then
		append-cflags $(test-flags-CC -ffat-lto-objects)
	fi

	if tc-is-cross-compiler; then
		# Force some tests that try to poke fs paths.
		export ac_cv_file__dev_ptc=no
		export ac_cv_file__dev_ptmx=yes
	fi

	# Export CXX so it ends up in /usr/lib/python3.X/config/Makefile.
	tc-export CXX

	local dbmliborder

	local myeconfargs=(
		# glibc-2.30 removes it; since we can't cleanly force-rebuild
		# Python on glibc upgrade, remove it proactively to give
		# a chance for users rebuilding python before glibc
		ac_cv_header_stropts_h=no

		--prefix=/usr/share/oem/python
		--with-platlibdir=$(get_libdir)
		--disable-shared
		--enable-ipv6
		--infodir='/discard/info'
		--mandir='/discard/man'
		--includedir='/discard/include'
		--with-computed-gotos
		--with-dbmliborder="${dbmliborder}"
		--with-libc=
		--enable-loadable-sqlite-extensions
		--without-ensurepip
		--without-system-expat
		--without-system-ffi
		--without-lto
		--disable-optimizations
	)

	OPT="" econf "${myeconfargs[@]}"

	if grep -q "#define POSIX_SEMAPHORES_NOT_ENABLED 1" pyconfig.h; then
		eerror "configure has detected that the sem_open function is broken."
		eerror "Please ensure that /dev/shm is mounted as a tmpfs with mode 1777."
		die "Broken sem_open function (bug 496328)"
	fi
}

src_compile() {
	# Ensure sed works as expected
	# https://bugs.gentoo.org/594768
	local -x LC_ALL=C
	# Prevent using distutils bundled by setuptools.
	# https://bugs.gentoo.org/823728
	export SETUPTOOLS_USE_DISTUTILS=stdlib

	emake CPPFLAGS= CFLAGS= LDFLAGS=
}

src_install() {
	local prefix=/usr/share/oem/python
	local eprefix="${ED}${prefix}"
	local elibdir="${eprefix}/$(get_libdir)"
	local epythonplatlibdir="${elibdir}/python${PYVER}"
	local bindir="${prefix}/bin"
	local ebindir="${eprefix}/bin"

	emake DESTDIR="${D}" altinstall

	# Remove static library
	rm "${elibdir}"/libpython*.a || die

	rm -r "${epythonplatlibdir}/"{sqlite3,test/test_sqlite*} || die
	rm -r "${ebindir}/idle${PYVER}" "${epythonplatlibdir}/"{idlelib,tkinter,test/test_tk*} || die

	# create a simple versionless 'python' symlink
	dosym "python${PYVER}" "${bindir}/python"
	dosym "python${PYVER}" "${bindir}/python3"

	rm -r "${ED}/discard" || die
}
