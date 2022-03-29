#!/bin/bash

   PROP_KEY=$1
   PROP_VALUE=`cat ./version.properties  | grep ANDROID_VERSION_NAME | cut -d'=' -f2`
   echo $PROP_VALUE
