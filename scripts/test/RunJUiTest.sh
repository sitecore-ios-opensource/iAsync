#!/bin/bash
#
#
#####################

echo "===============BEGIN JFFUITest==============="

IOS_VERSION=$1
CONFIGURATION=$2

APP_NAME=JFFUITest
LAUNCH_DIR=$PWD

echo arg1        - $1
echo IOS_VERSION - $IOS_VERSION

cd ../
  SCRIPTS_ROOT_DIR=$PWD
cd "$LAUNCH_DIR"

cd ../../
    PROJECT_ROOT=$PWD
cd "$LAUNCH_DIR"

cd "$PROJECT_ROOT/test/$APP_NAME"
pwd


KILL_SIMULATOR=$SCRIPTS_ROOT_DIR/simulator/KillSimulator.sh
LAUNCH_SIMULATOR=/usr/local/bin/ios-sim launch
LAUNCH_SIMULATOR_IOS_VERSION=--sdk $IOS_VERSION



xcodebuild -project $APP_NAME.xcodeproj -alltargets -configuration $CONFIGURATION -sdk iphonesimulator$IOS_VERSION clean build
if [ "$?" -ne "0" ]; then
   echo "[!!! ERROR !!!] : Build failed"
   echo xcodebuild -project $APP_NAME.xcodeproj -alltargets -configuration $CONFIGURATION -sdk iphonesimulator$IOS_VERSION clean build
   exit 1
fi


echo "-----"
echo IOS_VERSION $IOS_VERSION
echo CONFIGURATION $CONFIGURATION
echo APP_NAME $APP_NAME

echo LAUNCH_DIR $LAUNCH_DIR
echo SCRIPTS_ROOT_DIR $SCRIPTS_ROOT_DIR
echo PROJECT_ROOT $PROJECT_ROOT

echo KILL_SIMULATOR $KILL_SIMULATOR
echo LAUNCH_SIMULATOR $LAUNCH_SIMULATOR
echo LAUNCH_SIMULATOR_IOS_VERSION $LAUNCH_SIMULATOR_IOS_VERSION
echo "-----"


echo "-----Start Simulator-----"
BUILT_PRODUCTS_DIR=$( cat /tmp/${APP_NAME}Build/PRODUCT_DIR.txt )
cd "$BUILT_PRODUCTS_DIR/$CONFIGURATION-iphonesimulator"
/bin/bash "$KILL_SIMULATOR"
    $LAUNCH_SIMULATOR "$PWD/$APP_NAME.app" $LAUNCH_SIMULATOR_IOS_VERSION
/bin/bash "$KILL_SIMULATOR"
echo "-----Stopped Simulator-----"

cd "$LAUNCH_DIR"

echo "===============END JFFUITest==============="
