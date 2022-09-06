#!/bin/bash
#
# To change product/config/pkg.config
# add sanitizer option when scons compile
#

# define error code
E_Not_Match=1
E_File_Not_Exist=2

if [ $# -lt 1 ]; then
  echo -e "\nUsage: \t$0 product_dir\n"
  exit $E_Not_Match
fi

product_dir=$1
pkg_config=$product_dir/config/pkg.config
# check if pkg.config file exist
if [ ! -f "$pkg_config" ]; then
  echo "Cannot find $pkg_config"
  exit $E_File_Not_Exist
fi

# add sanitizer flag in pkg.config
echo "[NOTE] add sanitizer flag in $pkg_config"
sed -i 's/\${GSQL_BUILD_SCONS} utility/\${GSQL_BUILD_SCONS} addrcheck=true utility/g' $pkg_config
