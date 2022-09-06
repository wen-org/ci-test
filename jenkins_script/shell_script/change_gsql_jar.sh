#!/bin/bash
#
# This is to add gsql version file
# in gsql.jar
#

function gen_executable_jar () {
  local INJAR=$1
  local OUTJAR=$2
  cat <<EOF >$OUTJAR
#!/bin/bash
JAR=\$(dirname \$0)/.tmp_gsql.jar
sed -e '1,/^exit$/d' \$0 > \$JAR
java -jar \$JAR \$@
RC=\$?
exit \$RC
exit
EOF
  cat $INJAR >> $OUTJAR
}

PRODUCT=$1
PRODUCT=${PRODUCT:-~/product}

BUILDPATH=${PRODUCT}/build/debug/gle/
JETDIR=$PRODUCT/build/debug/gle-jet/
rm -rf $JETDIR
mkdir -p $JETDIR

#clean old builds
rm -rf $BUILDPATH
mkdir  $BUILDPATH
#go to build folder
cd $BUILDPATH

# extract gsql.jar
cp $PRODUCT/lib/gle/bin/gsql.jar .
bash gsql.jar config . -v &> /dev/null || :
mkdir tmp
cd tmp
jar xf ../.tmp_gsql.jar

# modify version file
RELEASE_VERSION_FILE=$PRODUCT/src/er/buildenv/gsql_release_version
if [ -f $RELEASE_VERSION_FILE ]; then
  # the version file contains verison and time properties
  # but commit number still keep
  COMMIT=$(grep "commit=" Version.prop | cut -d '=' -f 2)
  cp $RELEASE_VERSION_FILE Version.prop
  echo "commit="$COMMIT >> Version.prop
fi

#create jar file
JARFILE=$JETDIR/gsql.jar
echo -e "\nGenerating jar file $JARFILE"
jar cfm $JARFILE Manifest.txt ./*

new_jar=$JETDIR/new_gsql.jar
# make gsql.jar a executable script
gen_executable_jar $JARFILE $new_jar

# replace the old jar
cp $new_jar $PRODUCT/lib/gle/bin/gsql.jar
