Summary:            Advanced IP routing and network device configuration tools
Name:               iproute
Version:            %version
Release:            1%{?dist}
Group:              Applications/System
URL:                http://kernel.org/pub/linux/utils/net/%{name}2/
Source0:            http://kernel.org/pub/linux/utils/net/%{name}2/%{name}2-%{version}.tar.xz

# manpage/help improvements
#
# * Piece by piece absorbed upstream.
#
# https://github.com/pavlix/iproute2/commits/fedora

License:            GPLv2+ and Public Domain
BuildRequires:      bison
BuildRequires:      elfutils-libelf-devel
BuildRequires:      flex
BuildRequires:      iptables-devel >= 1.4.5
BuildRequires:      libdb-devel
BuildRequires:      libmnl-devel
BuildRequires:      libselinux-devel
BuildRequires:      linuxdoc-tools
BuildRequires:      pkgconfig
BuildRequires:      psutils
BuildRequires:      tex(cm-super-t1.enc)
BuildRequires:      tex(dvips)
BuildRequires:      tex(ecrm1000.tfm)
BuildRequires:      tex(latex)
#%if 0%{?fedora}
#BuildRequires:      linux-atm-libs-devel
#%endif
# For the UsrMove transition period
Conflicts:          filesystem < 3
Provides:           /sbin/ip

%description
The iproute package contains networking utilities (ip and rtmon, for example)
which are designed to use the advanced networking capabilities of the Linux
2.4.x and 2.6.x kernel.

%package doc
Summary:            Documentation for iproute2 utilities with examples
Group:              Applications/System
License:            GPLv2+

%description doc
The iproute documentation contains howtos and examples of settings.

%package devel
Summary:            iproute development files
Group:              Development/Libraries
License:            GPLv2+
Provides:           iproute-static = %{version}-%{release}

%description devel
The libnetlink static library.

%prep
%setup -q -n %{name}2-%{version}

%build
export CFLAGS="%{optflags}"
export LIBDIR=/%{_libdir}
export IPT_LIB_DIR=/%{_lib}/xtables
./configure
make %{?_smp_mflags}

%install
export DESTDIR='%{buildroot}'
export SBINDIR='%{_sbindir}'
export MANDIR='%{_mandir}'
export LIBDIR='%{_libdir}'
export CONFDIR='%{_sysconfdir}/iproute2'
export DOCDIR='%{_docdir}'
make install

# libnetlink
install -D -m644 include/libnetlink.h %{buildroot}%{_includedir}/libnetlink.h
install -D -m644 lib/libnetlink.a %{buildroot}%{_libdir}/libnetlink.a

# drop these files, iproute-doc package extracts files directly from _builddir
rm -rf '%{buildroot}%{_docdir}'

%files
%dir %{_sysconfdir}/iproute2
%{!?_licensedir:%global license %%doc}
%license COPYING
%doc README README*
%{_mandir}/man7/*
%{_mandir}/man8/*
%attr(644,root,root) %config(noreplace) %{_sysconfdir}/iproute2/*
%{_sbindir}/*
%dir %{_libdir}/tc/
%{_libdir}/tc/*
%{_datadir}/bash-completion/completions/tc

%files doc
%{!?_licensedir:%global license %%doc}
%license COPYING
%doc examples

%files devel
%{!?_licensedir:%global license %%doc}
%license COPYING
%{_mandir}/man3/*
%{_libdir}/libnetlink.a
%{_includedir}/libnetlink.h
%{_includedir}/iproute2/bpf_elf.h

%changelog
