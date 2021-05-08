#!/bin/bash

data_dir=$(pwd)

cd ~/dev/eclipse.jdt.ls/org.eclipse.jdt.ls.product/target/repository/

java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=1044      \
  -Declipse.application=org.eclipse.jdt.ls.core.id1                          \
  -Dosgi.bundles.defaultStartLevel=4                                         \
  -Declipse.product=org.eclipse.jdt.ls.core.product                          \
  -Dlog.level=ALL                                                            \
  -noverify                                                                  \
  -Xmx1G                                                                     \
  -jar ./plugins/org.eclipse.equinox.launcher_*.jar                          \
  -configuration ./config_linux                                              \
  -data $HOME/.eclipse.jd.ls                                                 \
  --add-modules=ALL-SYSTEM                                                   \
  --add-opens java.base/java.util=ALL-UNNAMED                                \
  --add-opens java.base/java.lang=ALL-UNNAMED
