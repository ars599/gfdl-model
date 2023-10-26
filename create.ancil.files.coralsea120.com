#!/bin/csh
#
#
module use /g/data/hh5/public/modules
module load conda/analysis3
module load matlab
module load matlab_licence/monash

set EXP = 'coralsea120'

set IDIR = '/g/data/w40/dxd565/gfdl-model/input-files/'
set WDIR = '/g/data/w40/dxd565/gfdl-model/experiments/'${EXP}'/input/'
set TDIR = '/g/data3/w40/dxd565/gfdl-model/tools-land-sea-mask-changes/cm2.1_paleo/'


cd $WDIR




#----------------------------------------
# change ocean bathymetry -> topo.nc and related grid files
echo 'step-1: change ocean bathymetry -> topo.nc and related grid files'
echo '     create idealised land with random bathymetry'
cat >script.m <<EOF


% read random bathymetry
filename ='topo.random.bathymetry-1.nc';
vinfo = ncinfo(filename);         % figure out what variables exist
for v = 1:length(vinfo.Variables) % this reads all variables
    dataset.(vinfo.Variables(v).Name) = ncread(filename,vinfo.Variables(v).Name); 
end
bathy = dataset.topo;

% read data   
filename ='topo.nc';
vinfo = ncinfo(filename);         % figure out what variables exist
for v = 1:length(vinfo.Variables) % this reads all variables
    dataset.(vinfo.Variables(v).Name) = ncread(filename,vinfo.Variables(v).Name); 
end

% define variables
xdim = 360;
ydim = 180;
topo = dataset.topo;
lon  = zeros(xdim,ydim); 
for n=1:xdim; lon(n,:) = dataset.lon(n); end
lat  = zeros(xdim,ydim); 
for n=1:ydim; lat(:,n) = dataset.lat(n); end

%  david: suggests that MOM does not like ocean over the tripolar grid points
%  MOM poles are located at (65N, 80E) and (65N, 100W).


% create new topo
topo_new = topo;

% idealised land-sea:
topo_new(:,:)       = -4000.;  % all oceans
topo_new(:,  1: 25) = 0.;      % include idealised antarctica
topo_new(:,151:170) = 0.;      % n-hemis idealised land circumpolar
topo_new(   1: 10, 61:120) = 0.; % tropical barrier 1
topo_new( 161:190, 61:120) = 0.; % tropical land
topo_new( 341:360, 61:120) = 0.; % tropical land

% smooth transition from land to ocean
mask = topo_new;
mask(topo_new >= 0.0) = 1;
mask(topo_new  < 0.0) = 0;

% approach 3: depth as function of distance to nearest land point
mask3(1:xdim,1:ydim)          = mask; 
mask3(xdim+1:2*xdim,1:ydim)   = mask;
mask3(2*xdim+1:3*xdim,1:ydim) = mask;
for i=1:xdim
	for j=1:ydim
        if (mask(i,j) == 0)
            % nearest land point
            idst = 1;
            for dx=1:ydim
                i1 = i-dx; i2 = i+dx; 
                j1 = j-dx; if (j1 < 1);    j1 = 1; end
                j2 = j+dx; if (j2 > ydim); j2 = ydim; end
                ss = sum(mask3(xdim+i1:xdim+i2,j1:j2),'all');
                if (ss > 0); break; end
                idst = idst +1;
            end
%            disp([num2str([i,j]), '  ',num2str(-100*idst)])
            topo_new(i,j) = -100*idst^1.5;
        end
    end
end

% deep ocean with random bathymetry
topo_new(topo_new < -4500.) = bathy(topo_new < -4500.);

% shallow tropical ocean
% ars599 23102023 triple the ocean depth
topo_new( 191:340, 61:120) = -120.; % shallow ocean

%random single point islands
ndim = 100;
for n=1:ndim
	irx = round(149*rand(1,1))+191;
	iry = round( 60*rand(1,1))+61;
	topo_new( irx:irx+1, iry:iry) = 0.;       % island 
end

% no points lower than 30m
topo_new(topo_new < 0 & topo_new > -25) = -30.;

% write file 
ncwrite(filename,'topo',topo_new);

quit
EOF
#
cp ${IDIR}topo_1x1.eocene.nc          topo.nc
cp ${IDIR}topo.random.bathymetry-1.nc topo.random.bathymetry-1.nc
# 
/apps/matlab/R2021b/bin/matlab -nodesktop -nodisplay -nosplash -r script  > out.matlab.1.txt
#
${TDIR}tools/make_topog --mosaic ${IDIR}ocean_mosaic.nc --vgrid ${IDIR}ocean_vgrid.nc --topog_type realistic --topog_file topo.nc --topog_field topo --scale_factor -1 --deepen_shallow




# create coupled mapping of land-sea mask files 
echo 'step-2: create coupled mapping of land-sea mask files'

${TDIR}tools/make_coupler_mosaic --atmos_mosaic ${IDIR}atmos_mosaic.nc --ocean_mosaic ${IDIR}ocean_mosaic.nc --ocean_topog topog.nc --land_mosaic ${IDIR}land_mosaic.nc

cp topog.nc                                  ../ancil/
cp atmos_mosaic_tile1Xocean_mosaic_tile1.nc  ../ancil/
cp atmos_mosaic_tile1Xland_mosaic_tile1.nc   ../ancil/
cp land_mosaic_tile1Xocean_mosaic_tile1.nc   ../ancil/
cp mosaic.nc 								 ../ancil/grid_spec.nc
cp land_mask.nc 							 ../ancil/
cp ocean_mask.nc 							 ../ancil/

cp topog.nc          topog.$EXP.nc                                 
cp land_mask.nc		 land_mask.$EXP.nc 							 
cp ocean_mask.nc     ocean_mask.$EXP.nc 							 





#----------------------------------------
# ATMOS: topography / initial geopotential for atmos ->  fv_rst.res.nc
echo 'step-3: topography / initial geopotential for atmos ->  fv_rst.res.nc'
cat >script.m <<EOF

g = 9.8;

% read land-sea mask (fraction) reference
filename = ['./land_mask.reference.nc'];
vinfo = ncinfo(filename);         % figure out what variables exist
for v = 1:length(vinfo.Variables) % this reads all variables
    dataset.(vinfo.Variables(v).Name) = ncread(filename,vinfo.Variables(v).Name); 
end
% vinfo.Variables.Name
mask_ref = dataset.mask;

% read land-sea mask (fraction) new
filename = ['./land_mask.nc'];
vinfo = ncinfo(filename);         % figure out what variables exist
for v = 1:length(vinfo.Variables) % this reads all variables
    dataset.(vinfo.Variables(v).Name) = ncread(filename,vinfo.Variables(v).Name); 
end
mask_new = dataset.mask;

% read atmos-topography dummy
outfile2 = ['./atmos-topography.nc'];
vinfo = ncinfo(outfile2);         % figure out what variables exist
for v = 1:length(vinfo.Variables) % this reads all variables
    dataset.(vinfo.Variables(v).Name) = ncread(outfile2,vinfo.Variables(v).Name); 
end
topo = dataset.topo;

% read atmos initital data   
outfile1 = ['./fv_rst.res.nc'];
vinfo = ncinfo(outfile1);         % figure out what variables exist
for v = 1:length(vinfo.Variables) % this reads all variables
    dataset.(vinfo.Variables(v).Name) = ncread(outfile1,vinfo.Variables(v).Name); 
end
gpot  =  dataset.Surface_geopotential;
T     =  dataset.T;
U     =  dataset.U;
V     =  dataset.V;
delp  =  dataset.DELP;
dims = size(T);
xdim = dims(1);
ydim = dims(2);
zdim = dims(3);

% topography at new oceans points 
topo(mask_new <= 0 )     = 0.;

% topography at new land points 
topo(mask_new > 0 )     =   300.*mask_new(mask_new > 0);


% desgin mountains
topo_new = topo;
for i=1:xdim
for j=1:ydim
    if( topo(i,j) > 0)
       % number of neighbours in x-direction
       isum = 1; 
       for ii=1:xdim % x up direction
           id = i+ii; if(id > xdim); id = id-xdim; end
           if( topo(id,j) >  0); isum = isum + 1; end
           if( topo(id,j) <= 0); break; end
       end
       isum1 = isum;
       isum = 1; 
       for ii=1:xdim % x down direction
           id = i-ii; if(id < 1); id = id+xdim; end
           if( topo(id,j) >  0); isum = isum + 1; end
           if( topo(id,j) <= 0); break; end
       end
       isum2 = isum;
       % number of neighbours in y-direction
       isum = 1; 
       for jj=1:ydim % y up direction
           jd = j+jj; if(jd > ydim); isum= ydim; break; end
           if( topo(i,jd) >  0); isum = isum + 1; end
           if( topo(i,jd) <= 0); break; end
       end
       isum3 = isum;
       isum = 1; 
       for jj=1:ydim % y down direction
           jd = j-jj; if(jd < 1); isum= ydim; break; end
           if( topo(i,jd) >  0); isum = isum + 1; end
           if( topo(i,jd) <= 0); break; end
       end
       isum4 = isum;
       dmin = min([isum1,isum2,isum3,isum4]);
       topo_new(i,j) = 100.*dmin;
    end
end; end
topo_x = topo_new;

% tropical land -> 10m height
topo_new(:,18:42) = 1/100*topo_x(:,18:42);

% n-hemis -> 1000m height max
topo_new(:,44:60) = 2*topo_x(:,44:60);
topo_new(topo_new > 1000.) = 1000.;

% antarctica -> 4000m height max
topo_new(:, 1:15) = 5*topo_x(:,1:15);


% compute new fields
gpot_new = g*topo_new; 
T_new    = T; 
U_new    = U; 
V_new    = V; 
delp_new = delp; 



% write file 
ncwrite(outfile1,'Surface_geopotential',gpot_new);
ncwrite(outfile1,'T',T_new);
ncwrite(outfile1,'U',U_new);
ncwrite(outfile1,'V',V_new);
ncwrite(outfile1,'DELP',delp_new);

ncwrite(outfile2,'topo',topo_new);


quit
EOF
# 
cp ${IDIR}land_mask.a55_c1.nc         land_mask.reference.nc
cp ${IDIR}fv_rst.res.original.nc      fv_rst.res.nc
cp ${IDIR}atmos-topography.dummy.nc   atmos-topography.nc

/apps/matlab/R2021b/bin/matlab -nodesktop -nodisplay -nosplash -r script > out.matlab.3.txt

cp fv_rst.res.nc  ../ancil/



#----------------------------------------
# ATMOS: create new river runoff -> 
echo 'step-4: create new river runoff -> river_destination_field'
#
echo '    compute downslopes'
cp ${IDIR}detail.rgb ./
python /g/data/w40/dxd565/gfdl-model/tools-land-sea-mask-changes/scripts/downslope_coarse.py
#
echo '    river destinations'
rm -f river_dest_Herold_drainage
cp atmos-topography_basins.txt Herold_drainage_basins.txt
/g/data/w40/dxd565/gfdl-model/tools-land-sea-mask-changes/input-files/make_river_dest.x > out.rivers.txt
#
cp  river_dest_Herold_drainage  ../ancil/river_destination_field






#----------------------------------------
# OCEAN: roughness_amp.nc
echo 'step-5: OCEAN: roughness_amp.nc'
cat >script.m <<EOF

% read land-sea mask
filename = ['./ocean_mask.nc'];
vinfo = ncinfo(filename);         % figure out what variables exist
for v = 1:length(vinfo.Variables) % this reads all variables
    dataset.(vinfo.Variables(v).Name) = ncread(filename,vinfo.Variables(v).Name); 
end
% vinfo.Variables.Name
mask = dataset.mask;

% read data   
filename = ['./roughness_amp.nc'];
vinfo = ncinfo(filename);         % figure out what variables exist
for v = 1:length(vinfo.Variables) % this reads all variables
    dataset.(vinfo.Variables(v).Name) = ncread(filename,vinfo.Variables(v).Name); 
end
vinfo.Variables.Name

roughness =  dataset.roughness_amp;
wet       =  dataset.wet;
dims = size(roughness);
xdim = dims(1);
ydim = dims(2);

% set new mask to the ocean mask
wet_new = mask; 

% write file 
ncwrite(filename,'wet',wet_new);

quit
EOF
# 
cp ${IDIR}roughness_amp.original.nc roughness_amp.nc
#
/apps/matlab/R2021b/bin/matlab -nodesktop -nodisplay -nosplash -r script  > out.matlab.4.txt
#
cp roughness_amp.nc  ../ancil/roughness_amp.nc





#----------------------------------------
# OCEAN: tideamp.nc
echo 'step-6: OCEAN: tideamp.nc'
cat >script.m <<EOF

% read land-sea mask
filename = ['./ocean_mask.nc'];
vinfo = ncinfo(filename);         % figure out what variables exist
for v = 1:length(vinfo.Variables) % this reads all variables
    dataset.(vinfo.Variables(v).Name) = ncread(filename,vinfo.Variables(v).Name); 
end
% vinfo.Variables.Name
mask = dataset.mask;

% read data   
filename = ['./tideamp.nc'];
vinfo = ncinfo(filename);         % figure out what variables exist
for v = 1:length(vinfo.Variables) % this reads all variables
    dataset.(vinfo.Variables(v).Name) = ncread(filename,vinfo.Variables(v).Name); 
end
vinfo.Variables.Name

tideamp  =  dataset.tideamp;
wet      =  dataset.wet;
dims = size(tideamp);
xdim = dims(1);
ydim = dims(2);

% set new mask to the ocean mask
wet_new = mask; 

% write file 
ncwrite(filename,'wet',wet_new);

quit
EOF
# 
cp ${IDIR}tideamp.original.nc tideamp.nc
#
/apps/matlab/R2021b/bin/matlab -nodesktop -nodisplay -nosplash -r script  > out.matlab.5.txt
#
cp tideamp.nc  ../ancil/tideamp.nc



#----------------------------------------
# ATMOS: Herold_cover_type_field.nc -> ground_type_field
echo 'step-7: ATMOS: Herold_cover_type_field.nc -> ground_type_field'
cat >script.m <<EOF

dir      = './';

% read land-sea mask new 
filename = [dir,'topo.nc'];
vinfo = ncinfo(filename);         % figure out what variables exist
for v = 1:length(vinfo.Variables) % this reads all variables
    dataset.(vinfo.Variables(v).Name) = ncread(filename,vinfo.Variables(v).Name); 
end
% vinfo.Variables.Name
topo = dataset.topo;
topo_new = topo;
topo_new(  1:180,:) = topo(181:360,:); % new mask points (is 180 shifted!!!)
topo_new(181:360,:) = topo(  1:180,:); % new mask points (is 180 shifted!!!)

% read data   
filename = [dir,'Herold_cover_type_field.nc'];
vinfo = ncinfo(filename);         % figure out what variables exist
for v = 1:length(vinfo.Variables) % this reads all variables
    dataset.(vinfo.Variables(v).Name) = ncread(filename,vinfo.Variables(v).Name); 
end
% vinfo.Variables.Name

cover  =  dataset.cover;

dims = size(cover);
xdim = dims(1);
ydim = dims(2);
lon  = zeros(xdim,ydim); 
for n=1:xdim; lon(n,:) = dataset.lon(n); end
lat  = zeros(xdim,ydim); 
for n=1:ydim; lat(:,n) = dataset.lat(n); end
 
% new mask points (is 180 shifted!!!)
cover_new = cover; 


% in Herold_cover_type_field.nc:
% antarctica     = mostly 6
%  6             = in many regions across latitudes
% midlat tropics = often 1

cover_new(:,:)       = 1;   % troics/midlat 
cover_new(:,   1:30) = 6;   % polar
cover_new(:,151:180) = 6;   % polar

cover_new(topo_new < 0 )   = NaN;   % oceans    

% write file 
ncwrite(filename,'cover',cover_new);

quit
EOF
# 
cp ${IDIR}Herold_cover_type_field.nc   Herold_cover_type_field.nc
#
/apps/matlab/R2021b/bin/matlab -nodesktop -nodisplay -nosplash -r script  > out.matlab.6.txt

# format transformations create -> ground_type_field
python /g/data3/w40/dxd565/mom/tools-land-sea-mask-changes/input-files/uniform_land.py
#
cp ground_type_field ../ancil/




#----------------------------------------
# ATMOS: biome_1x1.no-india.nc -> cover_type_field
echo 'step-8: ATMOS: biome_1x1.no-india.nc -> cover_type_field'
cat >script.m <<EOF

dir      = './';

% read land-sea mask new 
filename = [dir,'topo.nc'];
vinfo = ncinfo(filename);         % figure out what variables exist
for v = 1:length(vinfo.Variables) % this reads all variables
    dataset.(vinfo.Variables(v).Name) = ncread(filename,vinfo.Variables(v).Name); 
end
% vinfo.Variables.Name
topo = dataset.topo;
topo_new = topo;
topo_new(  1:180,:) = topo(181:360,:); % new mask points (is 180 shifted!!!)
topo_new(181:360,:) = topo(  1:180,:); % new mask points (is 180 shifted!!!)


% read data   
filename = [dir,'biome_1x1.nc'];
vinfo = ncinfo(filename);         % figure out what variables exist
for v = 1:length(vinfo.Variables) % this reads all variables
    dataset.(vinfo.Variables(v).Name) = ncread(filename,vinfo.Variables(v).Name); 
end
vinfo.Variables.Name

eocene_biome_zonal  =  dataset.eocene_biome_zonal_hp;
eocene_biome        =  dataset.eocene_biome_hp;
eocene_biome2       =  dataset.eocene_biome;
pi_biome            =  dataset.prei_biome_hp;
pi_biome2           =  dataset.prei_biome;

dims = size(eocene_biome_zonal);
xdim = dims(1);
ydim = dims(2);

% change values 
eocene_biome_zonal_new   = eocene_biome_zonal; 
eocene_biome_new         = eocene_biome;
eocene_biome2_new        = eocene_biome2;

for i=1:xdim
    for j=1:ydim
        if (topo_new(i,j) < 0 )
            eocene_biome_zonal_new(i,j) = eocene_biome_zonal(1,ydim);
            eocene_biome_new(i,j)       = eocene_biome(1,ydim);
            eocene_biome2_new(i,j)      = eocene_biome2(1,ydim);
        elseif(topo_new(i,j) >= 0 )
            eocene_biome_zonal_new(i,j) = 1.0;
            eocene_biome_new(i,j)       = 1.0;
            eocene_biome2_new(i,j)      = 1.0;
        end
    end
end

% write file 
ncwrite(filename,'eocene_biome_zonal_hp',eocene_biome_zonal_new);
ncwrite(filename,'eocene_biome_hp',eocene_biome_new);
ncwrite(filename,'eocene_biome',eocene_biome2_new);

quit
EOF
cp ${IDIR}biome_1x1.nc biome_1x1.nc
#
/apps/matlab/R2021b/bin/matlab -nodesktop -nodisplay -nosplash -r script > out.matlab.7.txt
#
# create -> cover_eo.nc
python /g/data3/w40/dxd565/mom/tools-land-sea-mask-changes/input-files/biome_to_veg.py
#
# create -> cover_type_field -> input file gfdl model
python /g/data3/w40/dxd565/mom/tools-land-sea-mask-changes/input-files/make_eo_cover.py
mv Herold_cover_type_field cover_type_field
cp cover_type_field  ../ancil/



#----------------------------------------
# ATMOS: atmos_topog_Herold.nc  -> mountain drag
echo 'step-9: ATMOS: atmos_topog_Herold.nc  -> mountain drag'
cat >script.m <<EOF

dir      = './';

% read land-sea mask new 
filename = [dir,'topo.nc'];
vinfo = ncinfo(filename);         % figure out what variables exist
for v = 1:length(vinfo.Variables) % this reads all variables
    dataset.(vinfo.Variables(v).Name) = ncread(filename,vinfo.Variables(v).Name); 
end
% vinfo.Variables.Name
topo = dataset.topo;
topo_new = topo;


% read data   
filename = [dir,'atmos_topog_Herold.nc'];
vinfo = ncinfo(filename);         % figure out what variables exist
for v = 1:length(vinfo.Variables) % this reads all variables
    dataset.(vinfo.Variables(v).Name) = ncread(filename,vinfo.Variables(v).Name); 
end
% vinfo.Variables.Name

zdat = dataset.zdat; 
dims = size(zdat);
xdim = dims(1);
ydim = dims(2);

% change values 
zdat_new = zdat; 
for i=1:xdim
    for j=1:ydim
        if ( topo_new(i,j) < 0 )
            zdat_new(i,j) = zdat(1,ydim);
        elseif( topo_new(i,j) >= 0 )
            zdat_new(i,j) = 850.0;
        end
    end
end


% write file 
ncwrite(filename,'zdat',zdat_new);

quit
EOF

cp ${IDIR}atmos_topog_Herold.nc atmos_topog_Herold.nc

/apps/matlab/R2021b/bin/matlab -nodesktop -nodisplay -nosplash -r script  > out.matlab.8.txt

cp atmos_topog_Herold.nc   ../ancil/



#----------------------------------------
# smooth ocean initital state -> ocean_temp_salt.res.nc
echo 'step-10: ocean initital state -> ocean_temp_salt.res.nc'
cat >script.m <<EOF

% read data   
filename ='ocean_temp_salt.res.nc';
vinfo = ncinfo(filename);         % figure out what variables exist
for v = 1:length(vinfo.Variables) % this reads all variables
    dataset.(vinfo.Variables(v).Name) = ncread(filename,vinfo.Variables(v).Name); 
end

% define variables
temp = dataset.temp;
salt = dataset.salt;

xdim = length(temp(:,1,1));

% new intitial state is zonal means
temp_new = temp;
salt_new = salt;
ztemp    = mean(temp,1);
zsalt    = mean(salt,1);
for i=1:xdim
	temp_new(i,:,:) = ztemp(1,:,:);
	salt_new(i,:,:) = zsalt(1,:,:);
end

% write file 
ncwrite(filename,'temp',temp_new);
ncwrite(filename,'salt',salt_new);

quit
EOF
#
cp ${IDIR}ocean_temp_salt.res.extrap.nc  ocean_temp_salt.res.nc
# 
/apps/matlab/R2021b/bin/matlab -nodesktop -nodisplay -nosplash -r script > out.matlab.1.txt

cp ocean_temp_salt.res.nc                ../ancil/ocean_temp_salt.res.zonal-mean.nc
cp ${IDIR}ocean_temp_salt.res.extrap.nc  ../ancil/ocean_temp_salt.res.nc

