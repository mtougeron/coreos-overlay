# Copyright 2011-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Flatcar: Based on systemd-245.5.ebuild from commit
# 960277ffec44c6245e1ae16b3b36fed9d76496b1 in gentoo repo.

EAPI=7

# Flatcar: Use cros setup
CROS_WORKON_PROJECT="flatcar-linux/systemd"
CROS_WORKON_REPO="git://github.com"

if [[ ${PV} == 9999 ]]; then
	# Flatcar: Use cros setup
	# Use ~arch instead of empty keywords for compatibility with cros-workon
	KEYWORDS="~amd64 ~arm64 ~arm ~x86"
else
	# Flatcar: Use cros setup
	CROS_WORKON_COMMIT="d5568ff804c2bda9a3869aa249bb6300aa3be7dd" # v245-flatcar
	KEYWORDS="~alpha amd64 ~arm arm64 ~ia64 ~ppc ~ppc64 ~sparc ~x86"
fi

# Flatcar: We still have python 3.5, and have no python3.8 yet.
PYTHON_COMPAT=( python3_{5,6,7} )

# Flatcar: cros-workon must be imported first, in cases where
# cros-workon and another eclass exports the same function (say
# src_compile) we want the later eclass's version to win. Only need
# src_unpack from workon.
inherit cros-workon

inherit bash-completion-r1 linux-info meson multilib-minimal ninja-utils pam python-any-r1 systemd toolchain-funcs udev user

DESCRIPTION="System and service manager for Linux"
HOMEPAGE="https://www.freedesktop.org/wiki/Software/systemd"

LICENSE="GPL-2 LGPL-2.1 MIT public-domain"
SLOT="0/2"
# Flatcar: Dropped cgroup-hybrid. We use legacy hierarchy by default
# to keep docker working. Dropped static-libs, we don't care about
# static libraries.
IUSE="acl apparmor audit build cryptsetup curl elfutils +gcrypt gnuefi homed http +hwdb idn importd +kmod +lz4 lzma nat pam pcre pkcs11 policykit pwquality qrcode repart +resolvconf +seccomp selinux +split-usr ssl +sysv-utils test vanilla xkb"

REQUIRED_USE="
	homed? ( cryptsetup )
	importd? ( curl gcrypt lzma )
"
RESTRICT="!test? ( test )"

MINKV="3.11"

OPENSSL_DEP=">=dev-libs/openssl-1.1.0:0="

COMMON_DEPEND=">=sys-apps/util-linux-2.30:0=[${MULTILIB_USEDEP}]
	sys-libs/libcap:0=[${MULTILIB_USEDEP}]
	acl? ( sys-apps/acl:0= )
	apparmor? ( sys-libs/libapparmor:0= )
	audit? ( >=sys-process/audit-2:0= )
	cryptsetup? ( >=sys-fs/cryptsetup-2.0.1:0= )
	curl? ( net-misc/curl:0= )
	elfutils? ( >=dev-libs/elfutils-0.158:0= )
	gcrypt? ( >=dev-libs/libgcrypt-1.4.5:0=[${MULTILIB_USEDEP}] )
	homed? ( ${OPENSSL_DEP} )
	http? (
		>=net-libs/libmicrohttpd-0.9.33:0=
		ssl? ( >=net-libs/gnutls-3.1.4:0= )
	)
	idn? ( net-dns/libidn2:= )
	importd? (
		app-arch/bzip2:0=
		sys-libs/zlib:0=
	)
	kmod? ( >=sys-apps/kmod-15:0= )
	lz4? ( >=app-arch/lz4-0_p131:0=[${MULTILIB_USEDEP}] )
	lzma? ( >=app-arch/xz-utils-5.0.5-r1:0=[${MULTILIB_USEDEP}] )
	nat? ( net-firewall/iptables:0= )
	pam? ( sys-libs/pam:=[${MULTILIB_USEDEP}] )
	pkcs11? ( app-crypt/p11-kit:0= )
	pcre? ( dev-libs/libpcre2 )
	pwquality? ( dev-libs/libpwquality:0= )
	qrcode? ( media-gfx/qrencode:0= )
	repart? ( ${OPENSSL_DEP} )
	seccomp? ( >=sys-libs/libseccomp-2.3.3:0= )
	selinux? ( sys-libs/libselinux:0= )
	xkb? ( >=x11-libs/libxkbcommon-0.4.1:0= )"

RDEPEND="${COMMON_DEPEND}
	sysv-utils? ( !sys-apps/sysvinit )
	!sysv-utils? ( sys-apps/sysvinit )
	resolvconf? ( !net-dns/openresolv )
	!build? ( || (
		sys-apps/util-linux[kill(-)]
		sys-process/procps[kill(+)]
		sys-apps/coreutils[kill(-)]
	) )
	!sys-auth/nss-myhostname
	!sys-fs/eudev
"

# sys-apps/dbus: the daemon only (+ build-time lib dep for tests)
#
# Flatcar: We don't have sys-fs/udev-init-scripts-25, so it's dropped.
PDEPEND=">=sys-apps/dbus-1.9.8[systemd]
	hwdb? ( >=sys-apps/hwids-20150417[udev] )
	policykit? ( sys-auth/polkit )
	!vanilla? ( sys-apps/gentoo-systemd-integration )"

BDEPEND="
	app-arch/xz-utils:0
	dev-util/gperf
	>=dev-util/meson-0.46
	>=dev-util/intltool-0.50
	>=sys-apps/coreutils-8.16
	sys-devel/m4
	virtual/pkgconfig
	test? ( sys-apps/dbus )
	app-text/docbook-xml-dtd:4.2
	app-text/docbook-xml-dtd:4.5
	app-text/docbook-xsl-stylesheets
	dev-libs/libxslt:0
	$(python_gen_any_dep 'dev-python/lxml[${PYTHON_USEDEP}]')
"

python_check_deps() {
	has_version -b "dev-python/lxml[${PYTHON_USEDEP}]"
}

pkg_pretend() {
	if [[ ${MERGE_TYPE} != buildonly ]]; then
		if use test && has pid-sandbox ${FEATURES}; then
			ewarn "Tests are known to fail with PID sandboxing enabled."
			ewarn "See https://bugs.gentoo.org/674458."
		fi

		local CONFIG_CHECK="~AUTOFS4_FS ~BLK_DEV_BSG ~CGROUPS
			~CHECKPOINT_RESTORE ~DEVTMPFS ~EPOLL ~FANOTIFY ~FHANDLE
			~INOTIFY_USER ~IPV6 ~NET ~NET_NS ~PROC_FS ~SIGNALFD ~SYSFS
			~TIMERFD ~TMPFS_XATTR ~UNIX
			~CRYPTO_HMAC ~CRYPTO_SHA256 ~CRYPTO_USER_API_HASH
			~!GRKERNSEC_PROC ~!IDE ~!SYSFS_DEPRECATED
			~!SYSFS_DEPRECATED_V2"

		use acl && CONFIG_CHECK+=" ~TMPFS_POSIX_ACL"
		use seccomp && CONFIG_CHECK+=" ~SECCOMP ~SECCOMP_FILTER"
		kernel_is -lt 3 7 && CONFIG_CHECK+=" ~HOTPLUG"
		kernel_is -lt 4 7 && CONFIG_CHECK+=" ~DEVPTS_MULTIPLE_INSTANCES"
		kernel_is -ge 4 10 && CONFIG_CHECK+=" ~CGROUP_BPF"

		if linux_config_exists; then
			local uevent_helper_path=$(linux_chkconfig_string UEVENT_HELPER_PATH)
			if [[ -n ${uevent_helper_path} ]] && [[ ${uevent_helper_path} != '""' ]]; then
				ewarn "It's recommended to set an empty value to the following kernel config option:"
				ewarn "CONFIG_UEVENT_HELPER_PATH=${uevent_helper_path}"
			fi
			if linux_chkconfig_present X86; then
				CONFIG_CHECK+=" ~DMIID"
			fi
		fi

		if kernel_is -lt ${MINKV//./ }; then
			ewarn "Kernel version at least ${MINKV} required"
		fi

		check_extra_config
	fi
}

pkg_setup() {
	:
}

src_unpack() {
	default
	# Flatcar: Use cros setup.
	cros-workon_src_unpack
}

src_prepare() {
	# Flatcar: We don't have separate patches, so no patching code here.
	#
	# Flatcar: Use the resolv.conf managed by systemd-resolved.
	sed -i -e 's,/run/systemd/resolve/stub-resolv.conf,/run/systemd/resolve/resolv.conf,' tmpfiles.d/etc.conf.m4 || die

	default
}

src_configure() {
	# Prevent conflicts with i686 cross toolchain, bug 559726
	tc-export AR CC NM OBJCOPY RANLIB

	python_setup

	multilib-minimal_src_configure
}

meson_use() {
	usex "$1" true false
}

meson_multilib() {
	if multilib_is_native_abi; then
		echo true
	else
		echo false
	fi
}

meson_multilib_native_use() {
	if multilib_is_native_abi && use "$1"; then
		echo true
	else
		echo false
	fi
}

multilib_src_configure() {
	local myconf=(
		--localstatedir="${EPREFIX}/var"
		# Flatcar: Point to our user mailing list.
		-Dsupport-url="https://groups.google.com/forum/#!forum/flatcar-linux-user"
		-Dpamlibdir="$(getpam_mod_dir)"
		# avoid bash-completion dep
		-Dbashcompletiondir="$(get_bashcompdir)"
		# make sure we get /bin:/sbin in PATH
		-Dsplit-usr=$(usex split-usr true false)
		-Dsplit-bin=true
		-Drootprefix="$(usex split-usr "${EPREFIX:-/}" "${EPREFIX}/usr")"
		-Drootlibdir="${EPREFIX}/usr/$(get_libdir)"
		# Avoid infinite exec recursion, bug 642724
		-Dtelinit-path="${EPREFIX}/lib/sysvinit/telinit"
		# no deps
		#
		# Flatcar: TODO: We have no clue why this was dropped
		# from upstream, so we keep it until we understand
		# more.
		-Defi=$(meson_multilib)
		-Dima=true
		# Flatcar: Use legacy hierarchy to avoid breaking
		# Docker.
		-Ddefault-hierarchy=legacy
		# Optional components/dependencies
		-Dacl=$(meson_multilib_native_use acl)
		-Dapparmor=$(meson_multilib_native_use apparmor)
		-Daudit=$(meson_multilib_native_use audit)
		-Dlibcryptsetup=$(meson_multilib_native_use cryptsetup)
		-Dlibcurl=$(meson_multilib_native_use curl)
		-Delfutils=$(meson_multilib_native_use elfutils)
		-Dgcrypt=$(meson_use gcrypt)
		-Dgnu-efi=$(meson_multilib_native_use gnuefi)
		-Defi-libdir="${ESYSROOT}/usr/$(get_libdir)"
		-Dhomed=$(meson_multilib_native_use homed)
		-Dhwdb=$(meson_multilib_native_use hwdb)
		-Dmicrohttpd=$(meson_multilib_native_use http)
		-Didn=$(meson_multilib_native_use idn)
		-Dimportd=$(meson_multilib_native_use importd)
		-Dbzip2=$(meson_multilib_native_use importd)
		-Dzlib=$(meson_multilib_native_use importd)
		-Dkmod=$(meson_multilib_native_use kmod)
		-Dlz4=$(meson_use lz4)
		-Dxz=$(meson_use lzma)
		-Dlibiptc=$(meson_multilib_native_use nat)
		-Dpam=$(meson_use pam)
		-Dp11kit=$(meson_multilib_native_use pkcs11)
		-Dpcre2=$(meson_multilib_native_use pcre)
		-Dpolkit=$(meson_multilib_native_use policykit)
		-Dpwquality=$(meson_multilib_native_use pwquality)
		-Dqrencode=$(meson_multilib_native_use qrcode)
		-Drepart=$(meson_multilib_native_use repart)
		-Dseccomp=$(meson_multilib_native_use seccomp)
		-Dselinux=$(meson_multilib_native_use selinux)
		-Ddbus=$(meson_multilib_native_use test)
		-Dxkbcommon=$(meson_multilib_native_use xkb)
		# Flatcar: Use our ntp servers.
		-Dntp-servers="0.flatcar.pool.ntp.org 1.flatcar.pool.ntp.org 2.flatcar.pool.ntp.org 3.flatcar.pool.ntp.org"
		# Breaks screen, tmux, etc.
		-Ddefault-kill-user-processes=false
		# Flatcar: TODO: Investigate if we want this.
		-Dcreate-log-dirs=false

		# multilib options
		-Dbacklight=$(meson_multilib)
		-Dbinfmt=$(meson_multilib)
		-Dcoredump=$(meson_multilib)
		-Denvironment-d=$(meson_multilib)
		-Dfirstboot=$(meson_multilib)
		-Dhibernate=$(meson_multilib)
		-Dhostnamed=$(meson_multilib)
		-Dldconfig=$(meson_multilib)
		-Dlocaled=$(meson_multilib)
		-Dman=$(meson_multilib)
		-Dnetworkd=$(meson_multilib)
		-Dquotacheck=$(meson_multilib)
		-Drandomseed=$(meson_multilib)
		-Drfkill=$(meson_multilib)
		-Dsysusers=$(meson_multilib)
		-Dtimedated=$(meson_multilib)
		-Dtimesyncd=$(meson_multilib)
		-Dtmpfiles=$(meson_multilib)
		-Dvconsole=$(meson_multilib)

		# Flatcar: Specify this, or meson breaks due to no
		# /etc/login.defs.
		-Dsystem-gid-max=999
		-Dsystem-uid-max=999

		# Flatcar: DBus paths.
		-Ddbussessionservicedir="${EPREFIX}/usr/share/dbus-1/services"
		-Ddbussystemservicedir="${EPREFIX}/usr/share/dbus-1/system-services"

		# Flatcar: PAM config directory.
		-Dpamconfdir=/usr/share/pam.d

		# Flatcar: The CoreOS epoch, Mon Jul 1 00:00:00 UTC
		# 2013. Used by timesyncd as a sanity check for the
		# minimum acceptable time. Explicitly set to avoid
		# using the current build time.
		-Dtime-epoch=1372636800

		# Flatcar: No default name servers.
		-Ddns-servers=

		# Flatcar: Disable the "First Boot Wizard", it isn't
		# very applicable to us.
		-Dfirstboot=false

		# Flatcar: Set latest network interface naming scheme
		# for
		# https://github.com/flatcar-linux/Flatcar/issues/36
		-Ddefault-net-naming-scheme=latest

		# Flatcar: Unported options, still needed?
		-Defi-cc="$(tc-getCC)"
		-Dquotaon-path=/usr/sbin/quotaon
		-Dquotacheck-path=/usr/sbin/quotacheck

		# Flatcar: No static libs.
	)

	meson_src_configure "${myconf[@]}"
}

multilib_src_compile() {
	eninja
}

multilib_src_test() {
	unset DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR
	meson_src_test
}

multilib_src_install() {
	DESTDIR="${D}" eninja install
}

multilib_src_install_all() {
	local rootprefix=$(usex split-usr '' /usr)

	# meson doesn't know about docdir
	mv "${ED}"/usr/share/doc/{systemd,${PF}} || die

	einstalldocs
	# Flatcar: Do not install sample nsswitch.conf, we don't
	# provide it.

	if ! use resolvconf; then
		rm -f "${ED}${rootprefix}"/sbin/resolvconf || die
	fi

	rm "${ED}"/etc/init.d/README || die
	rm "${ED}${rootprefix}"/lib/systemd/system-generators/systemd-sysv-generator || die

	if ! use sysv-utils; then
		rm "${ED}${rootprefix}"/sbin/{halt,init,poweroff,reboot,runlevel,shutdown,telinit} || die
		rm "${ED}"/usr/share/man/man1/init.1 || die
		rm "${ED}"/usr/share/man/man8/{halt,poweroff,reboot,runlevel,shutdown,telinit}.8 || die
	fi

	if ! use resolvconf && ! use sysv-utils; then
		rmdir "${ED}${rootprefix}"/sbin || die
	fi

	if use hwdb; then
		rm -r "${ED}${rootprefix}"/lib/udev/hwdb.d || die
	fi

	# Flatcar: Upstream uses keepdir commands to keep some empty
	# directories.
	#
	# Flatcar: TODO: Consider using that instead of
	# systemd_dotmpfilesd "${FILESDIR}"/systemd-flatcar.conf below.

	if use split-usr; then
		# Avoid breaking boot/reboot
		dosym ../../../lib/systemd/systemd /usr/lib/systemd/systemd
		dosym ../../../lib/systemd/systemd-shutdown /usr/lib/systemd/systemd-shutdown
	fi

	# Flatcar: Ensure journal directory has correct ownership/mode
	# in inital image.  This is fixed by systemd-tmpfiles *but*
	# journald starts before that and will create the journal if
	# the filesystem is already read-write.  Conveniently the
	# systemd Makefile sets this up completely wrong.
	#
	# Flatcar: TODO: Is this still a problem?
	dodir /var/log/journal
	fowners root:systemd-journal /var/log/journal
	fperms 2755 /var/log/journal

	# Flatcar: Don't prune systemd dirs.
	#
	# Flatcar: TODO: Upstream probably fixed it in different way -
	# it's using some keepdir commands.
	systemd_dotmpfilesd "${FILESDIR}"/systemd-flatcar.conf
	# Flatcar: Add tmpfiles rule for resolv.conf. This path has
	# changed after v213 so it must be handled here instead of
	# baselayout now.
	systemd_dotmpfilesd "${FILESDIR}"/systemd-resolv.conf

	# Flatcar: Don't default to graphical.target.
	local unitdir=$(PKG_CONFIG_LIBDIR="${PWD}/src/core" systemd_get_systemunitdir)
	dosym multi-user.target "${unitdir}"/default.target

	# Flatcar: Don't set any extra environment variables by default.
	rm "${ED}/usr/lib/environment.d/99-environment.conf" || die

	# Flatcar: Don't enable services in /etc, move to /usr.
	systemd_enable_service multi-user.target systemd-networkd.service
	systemd_enable_service multi-user.target systemd-resolved.service
	systemd_enable_service sysinit.target systemd-timesyncd.service

	# Flatcar: Enable getty manually.
	mkdir --parents "${ED}/usr/lib/systemd/system/getty.target.wants"
	dosym ../getty@.service "/usr/lib/systemd/system/getty.target.wants/getty@tty1.service"

	# Flatcar: Do not enable random services if /etc was detected
	# as empty!!!
	rm "${ED}$(usex split-usr '' /usr)/lib/systemd/system-preset/90-systemd.preset" || die
	insinto $(usex split-usr '' /usr)/lib/systemd/system-preset
	doins "${FILESDIR}"/99-default.preset

	# Flatcar: Do not ship distro-specific files (nsswitch.conf
	# pam.d). This conflicts with our own configuration provided
	# by baselayout.
	rm -rf "${ED}"/usr/share/factory
	sed -i "${ED}"/usr/lib/tmpfiles.d/etc.conf \
		-e '/^C!* \/etc\/nsswitch\.conf/d' \
		-e '/^C!* \/etc\/pam\.d/d' \
		-e '/^C!* \/etc\/issue/d'

	# Flatcar: gen_usr_ldscript is likely for static libs, so we
	# dropped it.
}

migrate_locale() {
	local envd_locale_def="${EROOT}/etc/env.d/02locale"
	local envd_locale=( "${EROOT}"/etc/env.d/??locale )
	local locale_conf="${EROOT}/etc/locale.conf"

	if [[ ! -L ${locale_conf} && ! -e ${locale_conf} ]]; then
		# If locale.conf does not exist...
		if [[ -e ${envd_locale} ]]; then
			# ...either copy env.d/??locale if there's one
			ebegin "Moving ${envd_locale} to ${locale_conf}"
			mv "${envd_locale}" "${locale_conf}"
			eend ${?} || FAIL=1
		else
			# ...or create a dummy default
			ebegin "Creating ${locale_conf}"
			cat > "${locale_conf}" <<-EOF
				# This file has been created by the sys-apps/systemd ebuild.
				# See locale.conf(5) and localectl(1).

				# LANG=${LANG}
			EOF
			eend ${?} || FAIL=1
		fi
	fi

	if [[ ! -L ${envd_locale} ]]; then
		# now, if env.d/??locale is not a symlink (to locale.conf)...
		if [[ -e ${envd_locale} ]]; then
			# ...warn the user that he has duplicate locale settings
			ewarn
			ewarn "To ensure consistent behavior, you should replace ${envd_locale}"
			ewarn "with a symlink to ${locale_conf}. Please migrate your settings"
			ewarn "and create the symlink with the following command:"
			ewarn "ln -s -n -f ../locale.conf ${envd_locale}"
			ewarn
		else
			# ...or just create the symlink if there's nothing here
			ebegin "Creating ${envd_locale_def} -> ../locale.conf symlink"
			ln -n -s ../locale.conf "${envd_locale_def}"
			eend ${?} || FAIL=1
		fi
	fi
}

save_enabled_units() {
	ENABLED_UNITS=()
	type systemctl &>/dev/null || return
	for x; do
		if systemctl --quiet --root="${ROOT:-/}" is-enabled "${x}"; then
			ENABLED_UNITS+=( "${x}" )
		fi
	done
}

pkg_preinst() {
	save_enabled_units {machines,remote-{cryptsetup,fs}}.target getty@tty1.service

	if ! use split-usr; then
		local dir
		for dir in bin sbin lib; do
			if [[ ! ${EROOT}/${dir} -ef ${EROOT}/usr/${dir} ]]; then
				eerror "\"${EROOT}/${dir}\" and \"${EROOT}/usr/${dir}\" are not merged."
				eerror "One of them should be a symbolic link to the other one."
				FAIL=1
			fi
		done
		if [[ ${FAIL} ]]; then
			eerror "Migration to system layout with merged directories must be performed before"
			eerror "rebuilding ${CATEGORY}/${PN} with USE=\"-split-usr\" to avoid run-time breakage."
			die "System layout with split directories still used"
		fi
	fi
}

pkg_postinst() {
       newusergroup() {
               enewgroup "$1"
               enewuser "$1" -1 -1 -1 "$1"
       }

       enewgroup input
       enewgroup kvm 78
       enewgroup render 30
       enewgroup systemd-journal
       newusergroup systemd-coredump
       newusergroup systemd-journal-remote
       newusergroup systemd-network
       newusergroup systemd-resolve
       newusergroup systemd-timesync

	systemd_update_catalog

	# Keep this here in case the database format changes so it gets updated
	# when required. Despite that this file is owned by sys-apps/hwids.
	if has_version "sys-apps/hwids[udev]"; then
		udevadm hwdb --update --root="${EROOT}"
	fi

	udev_reload || FAIL=1

	# Bug 465468, make sure locales are respect, and ensure consistency
	# between OpenRC & systemd
	migrate_locale

	# Flatcar: Reenabling systemd-timesyncd service too.
	systemd_reenable systemd-networkd.service systemd-resolved.service systemd-timesyncd.service

	if [[ ${ENABLED_UNITS[@]} ]]; then
		systemctl --root="${ROOT:-/}" enable "${ENABLED_UNITS[@]}"
	fi

	if [[ -z ${REPLACING_VERSIONS} ]]; then
		if type systemctl &>/dev/null; then
			systemctl --root="${ROOT:-/}" enable getty@.service remote-fs.target || FAIL=1
		fi
		elog "To enable a useful set of services, run the following:"
		elog "  systemctl preset-all --preset-mode=enable-only"
	fi

	if [[ -L ${EROOT}/var/lib/systemd/timesync ]]; then
		rm "${EROOT}/var/lib/systemd/timesync"
	fi

	if [[ -z ${ROOT} && -d /run/systemd/system ]]; then
		ebegin "Reexecuting system manager"
		systemctl daemon-reexec
		eend $?
	fi

	if [[ ${FAIL} ]]; then
		eerror "One of the postinst commands failed. Please check the postinst output"
		eerror "for errors. You may need to clean up your system and/or try installing"
		eerror "systemd again."
		eerror
	fi
}

pkg_prerm() {
	# If removing systemd completely, remove the catalog database.
	if [[ ! ${REPLACED_BY_VERSION} ]]; then
		rm -f -v "${EROOT}"/var/lib/systemd/catalog/database
	fi
}
