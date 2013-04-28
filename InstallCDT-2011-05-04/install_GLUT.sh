#!/bin/sh
installResources=`pwd`/Resources
scriptResources=$installResources/scripts

productFolder=/Developer/Cocotron/1.0
downloadFolder=$productFolder/Downloads

PREFIX=/Developer/Cocotron/1.0/Windows/i386/llvm-clang-trunk/i386-mingw32msvc/

$scriptResources/downloadFilesIfNeeded.sh $downloadFolder "http://www.opengl.org/resources/libraries/glut/glutdlls36.zip"

TMPDIR=/tmp/install_GLUT$$
mkdir $TMPDIR
cd $TMPDIR
unzip $downloadFolder/glutdlls36.zip

mkdir -p $PREFIX/bin
cp glut32.dll $PREFIX/bin

mkdir -p $PREFIX/lib
cp glut.lib $PREFIX/lib

mkdir -p $PREFIX/include/GLUT
cp glut.h $PREFIX/include/GLUT/GLUT.h


