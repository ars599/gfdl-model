#!/bin/csh
#
#
module use /g/data/hh5/public/modules
module load conda/analysis3-unstable

set NUM   = $1
set RUN   = a55_c1.run-$NUM

set PROJECT = w40
echo 'restart run:   '$RUN
#
cd /home/565/dxd565/gfdl-cm2.1/rundirs/$RUN
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
   - /g/data/w40/dxd565/mom/input/$RUN
exe: /g/data/w40/dxd565/mom/bin/fms_CM2M.x

qsub_flags: '-j oe'

storage:
      gdata:
            - w40
            - n69
            - hh5
      scratch:
            - w40
            - n69

collate:
   walltime: 01:00:00
   mem: 2GB
   exe: /g/data/w40/dxd565/mom/bin/mppnccombine

#postscript: moc.sh
restart_freq: 1
EOF
#
rm -rf  /scratch/${PROJECT}/dxd565/mom/work/$RUN/
payu sweep 
payu run -i 2 -n 49

exit


