#!/bin/bash
#
#

module use /g/data/hh5/public/modules
# module load conda/analysis3-unstable
module load conda/analysis3-22.07
module list

NUM=$1
RUN=a55_c1.run-$NUM

PROJECT=p66
echo 'restart run:   '$RUN
#
cd /home/599/ars599/gfdl-cm2.1/rundirs/$RUN
#
rm -f input.nml
ln -s input.96cpu.nml input.nml
#
cat > config.yaml <<EOF
queue: normal
project: $PROJECT
walltime: 4:00:00
ncpus: 96
mem: 60GB
jobname: gfdl-r$NUM

model: mom
input:
    - /g/data/p66/ars599/gfdl-model/input/$RUN
exe: /g/data/p66/ars599/gfdl-model/bin/fms_CM2M.x

qsub_flags: '-j oe'

storage:
      gdata:
            - w40
            - n69
            - hh5
            - p66
      scratch:
            - w40
            - n69
            - p66

collate:
   walltime: 01:00:00
   mem: 2GB
   exe: /g/data/p66/ars599/gfdl-model/bin/mppnccombine

#postscript: moc.sh
restart_freq: 1
EOF
#
rm -rf  /scratch/${PROJECT}/ars599/mom/work/$RUN/
payu sweep 
payu run -i 2 -n 49

exit
