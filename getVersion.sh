#!/bin/bash

   PROP_KEY=$1
   PROP_VALUE=`cat ./version.properties  | grep $PROP_KEY | cut -d'=' -f2`
   echo $PROP_VALUE
