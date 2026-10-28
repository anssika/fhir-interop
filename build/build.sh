#!/bin/bash

# exit immediately if any command fails (returns non-zero exit code)
set -e

# import all source code files into IRIS and compile
iris session IRIS < /opt/fhir-interop/build/build.script
