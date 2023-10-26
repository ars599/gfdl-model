#!/bin/bash
#
# This is a Bash script converted from the original tcsh script.

RUN=6
INPUT="/g/data/p66/ars599/gfdl-model/experiments/coralsea80/ancil/"
GDIR="/g/data/p66/ars599/gfdl-model/input/"
GDIR1="/g/data/w40/dxd565/gfdl-model/input/"
EXP="a55_c1.run-$RUN"
REF="a55_c1"
PROJECT="p66"

# Clean up the input folder
rm -r "${GDIR}${EXP}/"
mkdir "${GDIR}${EXP}/"

# Clean up the archive folder
rm -rf "/scratch/${PROJECT}/ars599/mom/archive/$EXP/"
rm -rf "/scratch/${PROJECT}/ars599/mom/work/$EXP/"
rm -rf "/home/599/ars599/gfdl-cm2.1/rundirs/$EXP/archive"
rm -rf "/home/599/ars599/gfdl-cm2.1/rundirs/$EXP/work"

# Link files needed for cold start that do not need to be changed for topo
# Take them from the reference experiment $REF
cd "${GDIR}${EXP}/"
ln -s ${GDIR1}${REF}/cns_*.nc .
ln -s ${GDIR1}${REF}/h2o* .
ln -s ${GDIR1}${REF}/id* .
ln -s ${GDIR1}${REF}/o3* .
ln -s ${GDIR1}${REF}/BetaDistributionTable.txt .
ln -s ${GDIR1}${REF}/Herold_aerosol_26lev.nc .
ln -s ${GDIR1}${REF}/Herold_topo_pad_2.nc .
ln -s ${GDIR1}${REF}/aerosol.optical.dat .
ln -s ${GDIR1}${REF}/albedo.data.nc .
ln -s ${GDIR1}${REF}/annual_mean_ozone .
ln -s ${GDIR1}${REF}/asmsw_data.nc .
ln -s ${GDIR1}${REF}/atmos_hgrid.nc .
ln -s ${GDIR1}${REF}/atmos_mosaic.nc .
ln -s ${GDIR1}${REF}/atmos_topo_stdev_Herold.nc .
ln -s ${GDIR1}${REF}/atmos_tracers.res.nc .
ln -s ${GDIR1}${REF}/conc_all.nc .
ln -s ${GDIR1}${REF}/eftsw4str .
ln -s ${GDIR1}${REF}/emissions.ch3i.GEOS4x5.nc .
ln -s ${GDIR1}${REF}/esf_sw_input_data_n38b18 .
ln -s ${GDIR1}${REF}/esf_sw_input_data_n72b25 .
ln -s ${GDIR1}${REF}/extlw_data.nc .
ln -s ${GDIR1}${REF}/extsw_data.nc .
ln -s ${GDIR1}${REF}/f113_gblannualdata .
ln -s ${GDIR1}${REF}/f11_gblannualdata .
ln -s ${GDIR1}${REF}/f12_gblannualdata .
ln -s ${GDIR1}${REF}/f22_gblannualdata .
ln -s ${GDIR1}${REF}/init_conditions.txt .
ln -s ${GDIR1}${REF}/land_hgrid.nc .
ln -s ${GDIR1}${REF}/land_mosaic.nc .
ln -s ${GDIR1}${REF}/lean_solar_spectral_data.dat .
ln -s ${GDIR1}${REF}/ocean_hgrid_1x1.5_82S.nc .
ln -s ${GDIR1}${REF}/ocean_mosaic.nc .
ln -s ${GDIR1}${REF}/ocean_vgrid.nc .
ln -s ${GDIR1}${REF}/omgsw_data.nc .
ln -s ${GDIR1}${REF}/radfn_5-2995_100-490k .
ln -s ${GDIR1}${REF}/randelo3data .
ln -s ${GDIR1}${REF}/seasonal_ozone .
ln -s ${GDIR1}${REF}/stdlvls .
ln -s ${GDIR1}${REF}/swstratendramadata .
ln -s ${GDIR1}${REF}/target_levs.txt .
ln -s ${GDIR1}${REF}/zonal_ozone_data.nc .
ln -s ${GDIR1}${REF}/ch4_gblannualdata .
ln -s ${GDIR1}${REF}/co2_gblannualdata .
ln -s ${GDIR1}${REF}/n2o_gblannualdata .

ln -s ${GDIR1}${REF}/groundwater_residence_time_field .

# Link files needed for cold start that need to be changed for topo
# Take them from the reference experiment $INPUT
ln -s ${INPUT}/atmos_mosaic_tile1Xland_mosaic_tile1.nc .
ln -s ${INPUT}/atmos_mosaic_tile1Xocean_mosaic_tile1.nc .
ln -s ${INPUT}/land_mosaic_tile1Xocean_mosaic_tile1.nc .
ln -s ${INPUT}/land_mask.nc .
ln -s ${INPUT}/ocean_mask.nc .
ln -s ${INPUT}/cover_type_field .
ln -s ${INPUT}/fv_rst.res.nc .
ln -s ${INPUT}/grid_spec.nc .
ln -s ${INPUT}/river_destination_field .
ln -s ${INPUT}/ground_type_field .
ln -s ${INPUT}/roughness_amp.nc .
ln -s ${INPUT}/tideamp.nc .
ln -s ${INPUT}/topog.nc .
ln -s ${INPUT}/atmos_topog_Herold.nc .
ln -s ${INPUT}/ocean_temp_salt.res.nc .


# Set cold start info
cat > coupler.res <<EOF
     4        (Calendar: no_calendar=0, thirty_day_months=1, julian=2, gregorian=3, noleap=4)
     1     1     1     0     0     0        Model start time:   year, month, day, hour, minute, second
     1     1     1     0     0     0        Current model time: year, month, day, hour, minute, second
EOF

# Namelist
cd /home/599/ars599/gfdl-cm2.1/rundirs/$EXP
rm -f input.nml
ln -s input.short-timestep.96cpu.nml input.nml

cat > config.yaml <<EOF
queue: normal
project: $PROJECT
walltime: 10:00:00
ncpus: 96
mem: 60GB
jobname: gfdl-r$RUN


model: mom
input: 
    - /g/data/p66/ars599/gfdl-model/input/a55_c1.run-$RUN
exe: /g/data/p66/ars599/gfdl-model/bin/fms_CM2M.x

#   - /g/data/w40/dxd565/mom/input/a55_c1.run-$RUN
#exe: /g/data/w40/dxd565/mom/bin/fms_CM2M.x

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
   exe:  /g/data/p66/ars599/gfdl-model/bin/mppnccombine

#   exe: /g/data/w40/dxd565/mom/bin/mppnccombine

#postscript: moc.sh
restart_freq: 1
EOF

# Submit the run
cd /home/599/ars599/gfdl-cm2.1/rundirs/$EXP
echo `pwd`
ls -lart

module use /g/data/hh5/public/modules
# module load conda/analysis3-unstable
module load conda/analysis3-22.07
module list

payu sweep
payu run -n 2

exit

