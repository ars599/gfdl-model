#!/bin/csh
#
#

set RUN      = 6
set INPUT   = /g/data/w40/dxd565/gfdl-model/experiments/coralsea/ancil/


set GDIR    = /g/data/w40/ars599/gfdl-model/input/
set EXP     = a55_c1.run-$RUN
set REF     = a55_c1
set PROJECT = w40

# ----------- clean up input folder ------------
rm -r ${GDIR}${EXP}/
mkdir ${GDIR}${EXP}/ 

# ----------- clean up archive folder ------------
rm -rf  /scratch/${PROJECT}/ars599/mom/archive/$EXP/
rm -rf  /scratch/${PROJECT}/ars599/mom/work/$EXP/
rm -rf  /home/599/ars599/gfdl-cm2.1/rundirs/$EXP/archive
rm -rf  /home/599/ars599/gfdl-cm2.1/rundirs/$EXP/work

# ----------- link files needed for cold start that do not need to be changed for topo ------------
# take them from the reference experiment $REF
cd    ${GDIR}${EXP}/  
ln -s ${GDIR}${REF}/cns_*.nc ./
ln -s ${GDIR}${REF}/h2o* ./
ln -s ${GDIR}${REF}/id* ./
ln -s ${GDIR}${REF}/o3* ./
ln -s ${GDIR}${REF}/BetaDistributionTable.txt ./
ln -s ${GDIR}${REF}/Herold_aerosol_26lev.nc ./
ln -s ${GDIR}${REF}/Herold_topo_pad_2.nc ./
ln -s ${GDIR}${REF}/aerosol.optical.dat ./
ln -s ${GDIR}${REF}/albedo.data.nc ./
ln -s ${GDIR}${REF}/annual_mean_ozone ./
ln -s ${GDIR}${REF}/asmsw_data.nc ./
ln -s ${GDIR}${REF}/atmos_hgrid.nc ./
ln -s ${GDIR}${REF}/atmos_mosaic.nc ./
ln -s ${GDIR}${REF}/atmos_topo_stdev_Herold.nc ./
ln -s ${GDIR}${REF}/atmos_tracers.res.nc ./
ln -s ${GDIR}${REF}/conc_all.nc ./
ln -s ${GDIR}${REF}/eftsw4str ./
ln -s ${GDIR}${REF}/emissions.ch3i.GEOS4x5.nc ./
ln -s ${GDIR}${REF}/esf_sw_input_data_n38b18 ./
ln -s ${GDIR}${REF}/esf_sw_input_data_n72b25 ./
ln -s ${GDIR}${REF}/extlw_data.nc ./
ln -s ${GDIR}${REF}/extsw_data.nc ./
ln -s ${GDIR}${REF}/f113_gblannualdata ./
ln -s ${GDIR}${REF}/f11_gblannualdata ./
ln -s ${GDIR}${REF}/f12_gblannualdata ./
ln -s ${GDIR}${REF}/f22_gblannualdata ./
ln -s ${GDIR}${REF}/init_conditions.txt ./
ln -s ${GDIR}${REF}/land_hgrid.nc ./
ln -s ${GDIR}${REF}/land_mosaic.nc ./
ln -s ${GDIR}${REF}/lean_solar_spectral_data.dat ./
ln -s ${GDIR}${REF}/ocean_hgrid_1x1.5_82S.nc ./
ln -s ${GDIR}${REF}/ocean_mosaic.nc ./
ln -s ${GDIR}${REF}/ocean_vgrid.nc ./
ln -s ${GDIR}${REF}/omgsw_data.nc ./
ln -s ${GDIR}${REF}/radfn_5-2995_100-490k ./
ln -s ${GDIR}${REF}/randelo3data ./
ln -s ${GDIR}${REF}/seasonal_ozone ./
ln -s ${GDIR}${REF}/stdlvls ./
ln -s ${GDIR}${REF}/swstratendramadata ./
ln -s ${GDIR}${REF}/target_levs.txt ./
ln -s ${GDIR}${REF}/zonal_ozone_data.nc ./
ln -s ${GDIR}${REF}/ch4_gblannualdata ./
ln -s ${GDIR}${REF}/co2_gblannualdata ./
ln -s ${GDIR}${REF}/n2o_gblannualdata ./

ln -s ${GDIR}${REF}/groundwater_residence_time_field ./

# ----------- link files needed for cold start that need to be changed for topo ------------
# take them from the reference experiment $INPUT

ln -s ${INPUT}/atmos_mosaic_tile1Xland_mosaic_tile1.nc ./
ln -s ${INPUT}/atmos_mosaic_tile1Xocean_mosaic_tile1.nc ./
ln -s ${INPUT}/land_mosaic_tile1Xocean_mosaic_tile1.nc ./
ln -s ${INPUT}/land_mask.nc ./
ln -s ${INPUT}/ocean_mask.nc ./
ln -s ${INPUT}/cover_type_field ./
ln -s ${INPUT}/fv_rst.res.nc ./
ln -s ${INPUT}/grid_spec.nc ./
ln -s ${INPUT}/river_destination_field ./
ln -s ${INPUT}/ground_type_field ./
ln -s ${INPUT}/roughness_amp.nc ./
ln -s ${INPUT}/tideamp.nc ./
ln -s ${INPUT}/topog.nc ./
ln -s ${INPUT}/atmos_topog_Herold.nc ./
ln -s ${INPUT}/ocean_temp_salt.res.nc ./

# set cold start info:
cat > coupler.res <<EOF
     4        (Calendar: no_calendar=0, thirty_day_months=1, julian=2, gregorian=3, noleap=4)
     1     1     1     0     0     0        Model start time:   year, month, day, hour, minute, second
     1     1     1     0     0     0        Current model time: year, month, day, hour, minute, second
EOF

# ----------- namelist ------------
cd /home/599/ars599/gfdl-cm2.1/rundirs/$EXP
#
# mv input.nml    input.original.nml
# mv config.yaml  config.original.yaml
#
rm -f input.nml
ln -s input.short-timestep.96cpu.nml   input.nml
#
cat >config.yaml <<EOF
queue: normal
project: $PROJECT
walltime: 10:00:00
ncpus: 96
mem: 60GB
jobname: gfdl-r$RUN

model: mom
input: 
   - /g/data/w40/dxd565/mom/input/a55_c1.run-$RUN
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

# ----------- submit run ------------
cd /home/599/ars599/gfdl-cm2.1/rundirs/$EXP
module use /g/data/hh5/public/modules
module load conda/analysis3-unstable
payu sweep
payu run -n 2

exit


