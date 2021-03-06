#!/bin/bash
#
#
#####################


echo "===============BEGIN JFFNetworkTest==============="

IOS_VERSION=$1
CONFIGURATION=$2

APP_NAME=JFFNetworkTest
LAUNCH_DIR=$PWD

echo arg1        - $1
echo IOS_VERSION - $IOS_VERSION

cd ../
    SCRIPTS_ROOT=$PWD
cd "$LAUNCH_DIR"
KILL_SIMULATOR=$SCRIPTS_ROOT/simulator/KillSimulator.sh


cd ../../
    PROJECT_ROOT=$PWD
cd "$LAUNCH_DIR"



cd "$PROJECT_ROOT/test/$APP_NAME"
pwd

xcodebuild -project $APP_NAME.xcodeproj -alltargets -configuration $CONFIGURATION -sdk iphonesimulator$IOS_VERSION clean build
if [ "$?" -ne "0" ]; then
   echo "[!!! ERROR !!!] : Build failed"
   echo xcodebuild -project $APP_NAME.xcodeproj -alltargets -configuration $CONFIGURATION -sdk iphonesimulator$IOS_VERSION clean build
   exit 1
fi


echo "-----Start Simulator-----"
BUILT_PRODUCTS_DIR=$( cat /tmp/${APP_NAME}Build/PRODUCT_DIR.txt )
cd "$BUILT_PRODUCTS_DIR/$CONFIGURATION-iphonesimulator"
/bin/bash "$KILL_SIMULATOR"
    iphonesim launch "$PWD/$APP_NAME.app" $IOS_VERSION 
/bin/bash "$KILL_SIMULATOR"
echo "-----Stopped Simulator-----"

cd "$LAUNCH_DIR"

echo "===============END JFFNetworkTest==============="