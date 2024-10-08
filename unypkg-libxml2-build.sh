#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2154

set -vx

######################################################################################################################
### Setup Build System and GitHub

#apt install -y

wget -qO- uny.nu/pkg | bash -s buildsys

### Installing build dependencies
unyp install python expat openssl

#pip3_bin=(/uny/pkg/python/*/bin/pip3)
#"${pip3_bin[0]}" install

### Getting Variables from files
UNY_AUTO_PAT="$(cat UNY_AUTO_PAT)"
export UNY_AUTO_PAT
GH_TOKEN="$(cat GH_TOKEN)"
export GH_TOKEN

source /uny/git/unypkg/fn
uny_auto_github_conf

######################################################################################################################
### Timestamp & Download

uny_build_date

mkdir -pv /uny/sources
cd /uny/sources || exit

pkgname="libxml2"
pkggit="https://github.com/GNOME/libxml2.git refs/tags/v*"
gitdepth="--depth=1"

### Get version info from git remote
# shellcheck disable=SC2086
latest_head="$(git ls-remote --refs --tags --sort="v:refname" $pkggit | grep -E "v[0-9.]*$" | tail --lines=1)"
latest_ver="$(echo "$latest_head" | grep -o "v[0-9.].*" | sed "s|v||")"
latest_commit_id="$(echo "$latest_head" | cut --fields=1)"

version_details

# Release package no matter what:
echo "newer" >release-"$pkgname"

git_clone_source_repo
version_details
archiving_source

######################################################################################################################
### Build

# unyc - run commands in uny's chroot environment
# shellcheck disable=SC2154
unyc <<"UNYEOF"
set -vx
source /uny/git/unypkg/fn

pkgname="libxml2"

version_verbose_log_clean_unpack_cd
get_env_var_values
get_include_paths

####################################################
### Start of individual build script

# Link libtool m4 files
automake_aclocal_dir=(/uny/pkg/automake/*/share/aclocal/)
echo "/uny/pkg/*/*/share/aclocal" >"${automake_aclocal_dir[0]}"dirlist

unset LD_RUN_PATH

./autogen.sh --prefix=/uny/pkg/"$pkgname"/"$pkgver" \
    --sysconfdir=/etc \
    --enable-static \
    --with-history \
    --docdir=/uny/pkg/"$pkgname"/"$pkgver"/share/doc/libxml2

make -j"$(nproc)"
make -j"$(nproc)" install

rm -vf /uny/pkg/"$pkgname"/"$pkgver"/lib/libxml2.la
cp -a /uny/pkg/"$pkgname"/"$pkgver"/include/libxml2/libxml/* /uny/pkg/"$pkgname"/"$pkgver"/include/
rm -rf /uny/pkg/"$pkgname"/"$pkgver"/include/libxml2/libxml
#rmdir /uny/pkg/"$pkgname"/"$pkgver"/include/libxml2
ln -s /uny/pkg/"$pkgname"/"$pkgver"/include /uny/pkg/"$pkgname"/"$pkgver"/include/libxml2/libxml
ln -s /uny/pkg/"$pkgname"/"$pkgver"/include /uny/pkg/"$pkgname"/"$pkgver"/include/libxml

####################################################
### End of individual build script

add_to_paths_files
dependencies_file_and_unset_vars
cleanup_verbose_off_timing_end
UNYEOF

######################################################################################################################
### Packaging

package_unypkg
