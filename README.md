# gfdl-model
N48 GFDL

Basic three steps:
 
(1) Creat ancillary files:
/g/data/w40/dxd565/gfdl-model/experiments/coralsea/create.ancil.files.coralsea.com<br />
 
(2) Setup and start the run:<br />
/g/data/w40/dxd565/gfdl-model/experiments/coralsea/gfdl-run.cold.start.coralsea.com<br />
 
(3) Change time step. The first 10yrs I run the model with a shorter time step and then switch to a longer time step to be faster: <br />
/g/data/w40/dxd565/gfdl-model/experiments/gfdl.restart.run.com [RUN-NUNBER]<br />
 
 


Simply setup GFDL CM2 N48 simple model for interbasin and other experiments

Main program

gfdl-model ] $ ls -la<br />
drwxr-sr-x    1 sul086   UsersGrp         0 Oct 26 13:56 bin<br />
-rwxr--r--    1 sul086   UsersGrp     18402 Oct 23 10:32 create.ancil.files.coralsea120.com<br />
-rwxr--r--    1 sul086   UsersGrp     18407 Oct 23 10:52 create.ancil.files.coralsea80.com<br />
drwxr-sr-x    1 sul086   UsersGrp         0 Oct 23 10:44 experiments<br />
-rwxr--r--    1 sul086   UsersGrp      4589 Oct 23 10:32 gfdl-run.cold.start.coralsea.com<br />
-rwxr--r--    1 sul086   UsersGrp       868 Oct 23 10:32 gfdl.restart.run.com<br />
drwxr-sr-x    1 sul086   UsersGrp         0 Oct 26 13:56 input<br />

Here are the original .com files using csh!

experiments/coralsea80/<br />
-rwxr--r--    1 sul086   UsersGrp     18451 Oct 25 20:16 create.ancil.files.coralsea80.com<br />
-rwxr-xr-x    1 sul086   UsersGrp      4697 Oct 26 00:35 gfdl-run.cold.start.coralsea.com.sh<br />
-rwxr-xr-x    1 sul086   UsersGrp       951 Oct 26 10:12 gfdl.restart.run.com.sh<br />

Here we use bash rather than csh<br />

