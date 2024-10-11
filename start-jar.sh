#!/bin/bash

clear

JAR_FILE=$(find target -maxdepth 1 -name "*.jar")
if [ ! -f "${JAR_FILE}" ]; then
  echo "Using jar file: ${JAR_FILE}"
fi

java \
  -jar "${JAR_FILE}"
