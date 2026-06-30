%bcond_with         asan

# This spec is a fork of avengemedia/danklinux's quickshell-git.spec
# (https://github.com/AvengeMedia/DankLinux, distro/fedora/quickshell), pinned
# to the same upstream commit they build, with a single extra patch applied:
#
#   PR #879: core/screen: retain removed screens to avoid use-after-free
#   https://github.com/quickshell-mirror/quickshell/pull/879
#
# It fixes intermittent segfaults on monitor wakeup under niri + DMS. Drop this
# COPR (and the distro/quickshell tree) once #879 lands upstream and avengemedia
# rebuilds. The Epoch bump below guarantees this build wins over avengemedia's
# until then; it is intentional and temporary.

%global commit      68c2c85c33845385f7ab8147b32f1450b1e468e0
%global commits     824
%global snapdate    20260619
%global tag         0.3.1
%global changelog_tag 0.3.0

Name:               quickshell-git
Epoch:              1
Version:            %{tag}^%{commits}.git%(c=%{commit}; echo ${c:0:7})
Release:            5.tishy1%{?dist}
Summary:            Flexible QtQuick based desktop shell toolkit

License:            LGPL-3.0-only AND GPL-3.0-only
URL:                https://github.com/quickshell-mirror/quickshell
Source0:            %{url}/archive/%{commit}/quickshell-%{commit}.tar.gz

# PR #879 (sunshowers:retain-removed-screens), applied via %%autosetup -p1.
Patch0:             0001-retain-removed-screens.patch

Conflicts:          quickshell <= %{tag}

%if 0%{?fedora}
%global crash_handler ON
BuildRequires:      cpptrace-devel
BuildRequires:      libdwarf-devel
BuildRequires:      pkgconfig(libzstd)
%else
%global crash_handler OFF
%endif

%if 0%{?fedora}
%global jemalloc_enabled ON
%else
%global jemalloc_enabled OFF
%endif
BuildRequires:      cmake
BuildRequires:      cmake(Qt6Core)
BuildRequires:      cmake(Qt6Qml)
BuildRequires:      cmake(Qt6ShaderTools)
BuildRequires:      cmake(Qt6WaylandClient)
BuildRequires:      gcc-c++
BuildRequires:      ninja-build
%if 0%{?fedora}
BuildRequires:      pkgconfig(CLI11)
%else
BuildRequires:      cli11-devel
%endif
BuildRequires:      pkgconfig(gbm)
BuildRequires:      pkgconfig(glib-2.0)
BuildRequires:      pkgconfig(polkit-agent-1)
%if 0%{?fedora}
BuildRequires:      pkgconfig(jemalloc)
%endif
BuildRequires:      pkgconfig(libdrm)
BuildRequires:      pkgconfig(libpipewire-0.3)
BuildRequires:      pkgconfig(pam)
BuildRequires:      pkgconfig(wayland-client)
BuildRequires:      pkgconfig(wayland-protocols)
BuildRequires:      qt6-qtbase-private-devel
BuildRequires:      spirv-tools

%if %{with asan}
BuildRequires:      libasan
%endif

Provides:           desktop-notification-daemon

%description
Flexible toolkit for making desktop shells with QtQuick, targeting
Wayland and X11.

%prep
%autosetup -n quickshell-%{commit} -p1

%build
%cmake  -GNinja \
%if %{with asan}
        -DASAN=ON \
%endif
        -DBUILD_SHARED_LIBS=OFF \
        -DCRASH_HANDLER=%{crash_handler} \
        -DUSE_JEMALLOC=%{jemalloc_enabled} \
        -DCMAKE_BUILD_TYPE=Release \
        -DDISTRIBUTOR="tishy COPR (quickshell PR#879 patched)" \
        -DGIT_REVISION=%{commit} \
        -DINSTALL_QML_PREFIX=%{_lib}/qt6/qml
%cmake_build

%install
%cmake_install

%files
%license LICENSE
%license LICENSE-GPL
%doc BUILD.md
%doc CONTRIBUTING.md
%doc README.md
%doc changelog/v%{changelog_tag}.md
%{_bindir}/qs
%{_bindir}/quickshell
%{_datadir}/applications/org.quickshell.desktop
%{_datadir}/icons/hicolor/scalable/apps/org.quickshell.svg
%{_libdir}/qt6/qml/Quickshell

%changelog
* Mon Jun 29 2026 Rain <rain@sunshowers.io> - 1:0.3.1^824.git68c2c85-5.tishy1
- Fork of avengemedia/danklinux quickshell-git at commit 68c2c85
- Apply PR #879 (retain removed screens) to fix monitor-wakeup use-after-free
- Epoch bump so this supersedes avengemedia/danklinux until #879 lands upstream
