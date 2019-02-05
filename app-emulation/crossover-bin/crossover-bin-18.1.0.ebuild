# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=5
PYTHON_COMPAT=( python2_7 )
PYTHON_REQ_USE="threads"

inherit python-single-r1 unpacker

DESCRIPTION="Commercial version of app-emulation/wine with paid support."
HOMEPAGE="http://www.codeweavers.com/products/crossover/"
SRC_URI="https://media.codeweavers.com/pub/crossover/cxlinux/demo/install-crossover-${PV}.bin"

LICENSE="CROSSOVER-3"
SLOT="0"
KEYWORDS="-* ~amd64 ~x86"
IUSE="+capi +cups doc +gphoto2 +gsm +jpeg +lcms +ldap +mp3 +nls +openal +opencl +opengl +png +scanner +ssl +v4l"
RESTRICT="bindist test"
QA_FLAGS_IGNORED="opt/cxoffice/.*"
QA_PRESTRIPPED="opt/cxoffice/lib/.*
	opt/cxoffice/bin/cxburner
	opt/cxoffice/bin/cxntlm_auth
	opt/cxoffice/bin/wineserver
	opt/cxoffice/bin/unrar
	opt/cxoffice/bin/wine-preloader
	opt/cxoffice/bin/cxdiag
	opt/cxoffice/bin/cxgettext
	opt/cxoffice/bin/wineloader
	"
S="${WORKDIR}"

DEPEND="dev-lang/perl
	app-arch/unzip
	${PYTHON_DEPS}"

RDEPEND="${DEPEND}
	!prefix? ( sys-libs/glibc )
	>=dev-python/pygtk-2.10[${PYTHON_USEDEP}]
	dev-python/dbus-python[${PYTHON_USEDEP}]
	dev-util/desktop-file-utils
	!app-emulation/crossover-office-pro-bin
	!app-emulation/crossover-office-bin
	capi? ( net-libs/libcapi )
	cups? ( net-print/cups )
	gsm? ( media-sound/gsm )
	jpeg? ( virtual/jpeg )
	lcms? ( media-libs/lcms:2 )
	ldap? ( net-nds/openldap )
	gphoto2? ( media-libs/libgphoto2 )
	mp3? ( >=media-sound/mpg123-1.5.0 )
	nls? ( sys-devel/gettext )
	openal? ( media-libs/openal )
	opencl? ( virtual/opencl )
	opengl? (
		virtual/glu
		virtual/opengl
	)
	png? ( media-libs/libpng:0 )
	scanner? ( media-gfx/sane-backends )
	ssl? ( dev-libs/openssl:0 )
	v4l? ( media-libs/libv4l )
	media-libs/alsa-lib
	>=media-libs/freetype-2.0.0
	media-libs/mesa
	sys-auth/nss-mdns
	sys-apps/util-linux
	sys-libs/ncurses:5/5
	sys-libs/zlib
	x11-libs/libICE
	x11-libs/libSM
	x11-libs/libX11
	x11-libs/libXau
	x11-libs/libXdmcp
	x11-libs/libXext
	x11-libs/libXi
	x11-libs/libXrandr
	x11-libs/libXxf86vm
	x11-libs/libxcb"

pkg_nofetch() {
	einfo "Please visit ${HOMEPAGE}"
	einfo "and place ${A} in ${DISTDIR}"
}

src_unpack() {
	# self unpacking zip archive; unzip warns about the exe stuff
	unpack_zip ${A}
}

src_prepare() {
	python_fix_shebang .

	sed -i \
		-e "s:xdg_install_icons(:&\"${ED}\".:" \
		-e "s:\"\(.*\)/applications:\"${ED}\1/applications:" \
		-e "s:\"\(.*\)/desktop-directories:\"${ED}\1/desktop-directories:" \
		"${S}/lib/perl/CXMenuXDG.pm"

	# Remove unnecessary files
	rm -r license.txt guis/ || die "Could not remove files"
	use doc || rm -r doc/ || die "Could not remove files"
}

src_install() {
	# Install crossover symlink, bug #476314
	dosym ../cxoffice/bin/crossover /opt/bin/crossover

	# Install documentation
	dodoc README changelog.txt
	rm README changelog.txt || die "Could not remove README and changelog.txt"

	# Install files
	dodir /opt/cxoffice
	#cp -r ./* "${ED}opt/cxoffice" \
	find . | cpio -dumpl "${ED}/opt/cxoffice" 2>/dev/null \
		|| die "Could not install into ${ED}opt/cxoffice"

	# Install configuration file
	insinto /opt/cxoffice/etc
	doins share/crossover/data/cxoffice.conf

	# Konqueror in its infinite wisdom decides to try opening things for
	# writing, which are sandbox violations. This breaks the install process if
	# it is installed, so we ninja edit it to false so it so doesn't run.
	sed -i -e 's/cxwhich konqueror/false &/' "${ED}opt/cxoffice/bin/locate_gui.sh" \
		|| die "Could not apply workaround for konqueror"

	# Install menus
	# XXX: locate_gui.sh automatically detects *-application-merged directories
	# This means what we install will vary depending on the contents of
	# /etc/xdg, which is a QA violation. It is not clear how to resolve this.
	XDG_DATA_HOME="/usr/share" XDG_CONFIG_HOME="/etc/xdg" \
		"${ED}opt/cxoffice/bin/cxmenu" --destdir="${ED}" --crossover --install \
		|| die "Could not install menus"

	# Revert ninja edit
	sed -i -e 's/false \(cxwhich konqueror\)/\1/' "${ED}opt/cxoffice/bin/locate_gui.sh" \
		|| die "Could not apply workaround for konqueror"

	rm "${ED}usr/share/applications/"*"Uninstall CrossOver Linux.desktop" \
		|| die "Could not remove uninstall menus"
	sed -i \
		-e "s:\"${ED}\".::" \
		-e "s:${ED}::" \
		"${ED}/opt/cxoffice/lib/perl/CXMenuXDG.pm" \
		|| die "Could not fix paths in ${ED}/opt/cxoffice/lib/perl/CXMenuXDG.pm"
	sed -i -e "s:${ED}:/:" \
		"${ED}usr/share/applications/"*"CrossOver.desktop" \
		|| die "Could not fix paths of *.desktop files"
}

pkg_postinst() {
	einfo "${P} is open source software with the exception of the GUI."
	einfo "Source code can be obtained from:"
	einfo
	einfo "https://media.codeweavers.com/pub/crossover/source/crossover-sources-${PV}.tar.gz"
}
