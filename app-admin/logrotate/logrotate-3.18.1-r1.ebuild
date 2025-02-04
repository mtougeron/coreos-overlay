# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit systemd tmpfiles

DESCRIPTION="Rotates, compresses, and mails system logs"
HOMEPAGE="https://github.com/logrotate/logrotate"
SRC_URI="https://github.com/${PN}/${PN}/releases/download/${PV}/${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~alpha amd64 arm arm64 ~hppa ~ia64 ~m68k ~mips ppc ppc64 ~riscv ~s390 sparc x86"
IUSE="acl +cron selinux"

DEPEND="
	>=dev-libs/popt-1.5
	selinux? ( sys-libs/libselinux )
	acl? ( virtual/acl )"
RDEPEND="${DEPEND}
	selinux? ( sec-policy/selinux-logrotate )
	cron? ( virtual/cron )"

STATEFILE="${EPREFIX}/var/lib/misc/logrotate.status"
OLDSTATEFILE="${EPREFIX}/var/lib/logrotate.status"

move_old_state_file() {
	elog "logrotate state file is now located at ${STATEFILE}"
	elog "See bug #357275"
	if [[ -e "${OLDSTATEFILE}" ]] ; then
		elog "Moving your current state file to new location: ${STATEFILE}"
		mv -n "${OLDSTATEFILE}" "${STATEFILE}" || die
	fi
}

install_cron_file() {
	exeinto /etc/cron.daily
	newexe "${S}"/examples/logrotate.cron "${PN}"
}

PATCHES=(
	"${FILESDIR}/${PN}-3.15.0-ignore-hidden.patch"
)

src_prepare() {
	sed -i -e 's#/usr/sbin/logrotate#/usr/bin/logrotate#' examples/logrotate.{cron,service} || die
	default
}

src_configure() {
	econf \
		$(use_with acl) \
		$(use_with selinux) \
		--with-state-file-path="${STATEFILE}"
}

src_test() {
	emake test
}

src_install() {
	dobin logrotate
	doman logrotate.8
	dodoc ChangeLog.md

	insinto /usr/share/logrotate
	doins "${FILESDIR}"/logrotate.conf

	use cron && install_cron_file

	systemd_dounit examples/logrotate.timer
	systemd_dounit "${FILESDIR}"/logrotate.service
	systemd_enable_service multi-user.target logrotate.timer
	newtmpfiles "${FILESDIR}"/${PN}.tmpfiles ${PN}.conf

	keepdir /etc/logrotate.d
}

pkg_postinst() {
	elog
	elog "The ${PN} binary is now installed under /usr/bin. Please"
	elog "update your links"
	elog

	move_old_state_file

	tmpfiles_process ${PN}.conf

	if [[ -z ${REPLACING_VERSIONS} ]] ; then
		elog "If you wish to have logrotate e-mail you updates, please"
		elog "emerge virtual/mailx and configure logrotate in"
		elog "/etc/logrotate.conf appropriately"
		elog
		elog "Additionally, /etc/logrotate.conf may need to be modified"
		elog "for your particular needs. See man logrotate for details."
	fi
}
