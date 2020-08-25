# Defined in - @ line 1
function ottobsp --wraps='cd src/otto-bsp && bax source setup-environment build && cd workspace/sources/otto-core' --wraps='cd ~/src/otto-bsp && bax source setup-environment build && cd workspace/sources/otto-core' --description 'alias ottobsp cd ~/src/otto-bsp && bax source setup-environment build && cd workspace/sources/otto-core'
  cd ~/src/otto-bsp && bax source setup-environment build && cd workspace/sources/otto-core $argv;
end
