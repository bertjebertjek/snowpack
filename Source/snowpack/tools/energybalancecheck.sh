#!/bin/bash
# Provide *.met or *.smet file as first argument.
# Example for quickly plotting in gnuplot the energy balance, provided the output file is called output.txt:
# pl "<(cat ./output.txt | awk '{sum+=$16; print sum}')" u 1 w l title 'energy in', "<(cat ./output.txt | awk '{sum+=$17; print -1.0*sum}')" w l title 'energy out', "<(cat ./output.txt | awk '{sum+=$15; print 1.0*sum}')" w l title 'storage'
if [ $# -lt 1 ]; then
	echo "This script reads a *.met or *.smet-file (provided as first argument) and writes the energy balance on the stdout and statistics to stderr." > /dev/stderr
	echo "Invoke with: ./energybalancecheck.sh <(s)met file> [firstdate=YYYYMMDD] [lastdate=YYYYMMDD]" > /dev/stderr
	echo "" > /dev/stderr
	echo "Note: 1) the energy balance represents only the snow cover energy balance!" > /dev/stderr
	echo "      2) the energy balance can only be properly checked when the output resolution of the (s)met file is the" > /dev/stderr
	echo "         same as the snowpack calculation step length." > /dev/stderr
	echo "      3) using options firstdate and lastdate, one can define a period over which the mass balance should be" > /dev/stderr
	echo "         determined. Default is full period in (s)met-file. No spaces in command line options are allowed!" > /dev/stderr
	echo "" > /dev/stderr
	echo "Examples:" > /dev/stderr
	echo " ./energybalancecheck.sh WFJ2_flat.met > output.txt       Writes energy balance in output.txt and shows overall energy balance statistics on screen." > /dev/stderr
	echo " ./energybalancecheck.sh WFJ2_flat.met > /dev/null        Just shows overall energy balance statistics on screen." > /dev/stderr
	echo " ./energybalancecheck.sh WFJ2_flat.smet | less            View the energy balance in less." > /dev/stderr
	echo " ./energybalancecheck.sh WFJ2_flat.smet firstdate=20071001 lastdate=20080323" > /dev/stderr
	echo "                                                          Determines energy balance between 1st of October 2007 up to and including 23rd of March 2008." > /dev/stderr
	exit
fi


# Initial settings
firstdate=0
lastdate=99999999


# Get met file name from first argument
file=$1
if [[ ${file} == *.met ]]; then
	met_file=${file}
	met=1
	smet=0
	field_sep=","
elif [[ ${file} == *.smet ]]; then
	smet_file=${file}
	met=0
	smet=1
	field_sep=" "
else
	echo "energybalancecheck.sh: ERROR: file ${file} does not have *.met or *.smet file extension!" > /dev/stderr
	exit
fi


# Read command line parameters
if [ $# -gt 1 ]; then
	for i in `seq 2 $#`
	do
		eval "let \$$i"
	done
fi


# Check if file exists
if [ ! -f "${file}" ]; then
	echo "energybalancecheck.sh: ERROR: file ${file} does not exist, is not a file, or cannot be opened!" > /dev/stderr
	exit
fi


# Check if file is not empty
if [ ! -s "${file}" ]; then
	echo "energybalancecheck.sh: ERROR: file ${file} is empty!" > /dev/stderr
	exit
fi


# Read header from met file
if (( ${met} )); then
	header=$(head -100 ${met_file} | grep -m 1 ^ID)
	if [ -z "${header}" ]; then
		echo "energybalancecheck.sh: ERROR: no header found in ${met_file}." > /dev/stderr
		exit
	fi
	# Determine column mapping
	#  -- date and time
	coldatetime=$(echo ${header} | sed 's/,/\n/g' | grep -nx "Date" | awk -F: '{print $1}')

	#  -- snow height
	colhsmeasured=$(echo ${header} | sed 's/,/\n/g' | grep -nx "Measured snow depth HS" | awk -F: '{print $1}')
	colhsmodel=$(echo ${header} | sed 's/,/\n/g' | grep -nx "Modelled snow depth (vertical)" | awk -F: '{print $1}')

	#  -- energy balance terms
	colSHF=$(echo ${header} | sed 's/,/\n/g' | grep -nx "Sensible heat" | awk -F: '{print $1}')
	colLHF=$(echo ${header} | sed 's/,/\n/g' | grep -nx "Latent heat" | awk -F: '{print $1}')
	colOLWR=$(echo ${header} | sed 's/,/\n/g' | grep -nx "Outgoing longwave radiation" | awk -F: '{print $1}')
	colILWR=$(echo ${header} | sed 's/,/\n/g' | grep -nx "Incoming longwave radiation" | awk -F: '{print $1}')
	colNetLWR=$(echo ${header} | sed 's/,/\n/g' | grep -nx "Net absorbed longwave radiation" | awk -F: '{print $1}')
	colRSWR=$(echo ${header} | sed 's/,/\n/g' | grep -nx "Reflected shortwave radiation" | awk -F: '{print $1}')
	colISWR=$(echo ${header} | sed 's/,/\n/g' | grep -nx "Incoming shortwave radiation" | awk -F: '{print $1}')
	colsoilheat=$(echo ${header} | sed 's/,/\n/g' | grep -nx "Heat flux at ground surface" | awk -F: '{print $1}')
	colRainNRG=$(echo ${header} | sed 's/,/\n/g' | grep -nx "Heat advected to the surface by liquid precipitation" | awk -F: '{print $1}')
	colIntNRG=$(echo ${header} | sed 's/,/\n/g' | grep -nx "Internal energy change" | awk -F: '{print $1}')
	colPhchEnergy=$(echo ${header} | sed 's/,/\n/g' | grep -nx "Melt freeze part of internal energy change" | awk -F: '{print $1}')
elif (( ${smet} )); then
	header=$(head -100 ${smet_file} | grep -m 1 ^fields)
	if [ -z "${header}" ]; then
		echo "energybalancecheck.sh: ERROR: no header found in ${smet_file}." > /dev/stderr
		exit
	fi
	# Determine column mapping
	#  -- date and time
	coldatetime=$(echo ${header} | sed 's/ /\n/g' | grep -nx "timestamp" | awk -F: '{print $1-2}')

	#  -- snow height
	colhsmeasured=$(echo ${header} | sed 's/ /\n/g' | grep -nx "HS_meas" | awk -F: '{print $1-2}')
	colhsmodel=$(echo ${header} | sed 's/ /\n/g' | grep -nx "HS_mod" | awk -F: '{print $1-2}')

	#  -- energy balance terms
	colSHF=$(echo ${header} | sed 's/ /\n/g' | grep -nx "Qs" | awk -F: '{print $1-2}')
	colLHF=$(echo ${header} | sed 's/ /\n/g' | grep -nx "Ql" | awk -F: '{print $1-2}')
	colOLWR=$(echo ${header} | sed 's/ /\n/g' | grep -nx "OLWR" | awk -F: '{print $1-2}')
	colILWR=$(echo ${header} | sed 's/ /\n/g' | grep -nx "ILWR" | awk -F: '{print $1-2}')
	colNetLWR=$(echo ${header} | sed 's/ /\n/g' | grep -nx "LWR_net" | awk -F: '{print $1-2}')
	colRSWR=$(echo ${header} | sed 's/ /\n/g' | grep -nx "OSWR" | awk -F: '{print $1-2}')
	colISWR=$(echo ${header} | sed 's/ /\n/g' | grep -nx "ISWR" | awk -F: '{print $1-2}')
	colsoilheat=$(echo ${header} | sed 's/ /\n/g' | grep -nx "Qg0" | awk -F: '{print $1-2}')
	colRainNRG=$(echo ${header} | sed 's/ /\n/g' | grep -nx "Qr" | awk -F: '{print $1-2}')
	colIntNRG=$(echo ${header} | sed 's/ /\n/g' | grep -nx "dIntEnergySnow" | awk -F: '{print $1-2}')
	colPhchEnergy=$(echo ${header} | sed 's/ /\n/g' | grep -nx "meltFreezeEnergySnow" | awk -F: '{print $1-2}')
fi


error=0
if [ -z "${coldatetime}" ]; then
	echo "energybalancecheck.sh: ERROR: date/time not found in one of the columns." > /dev/stderr
	error=1
fi
if [ -z "${colhsmeasured}" ]; then
	echo "energybalancecheck.sh: ERROR: measured hs not found in one of the columns." > /dev/stderr
	error=1
fi
if [ -z "${colhsmodel}" ]; then
	echo "energybalancecheck.sh: ERROR: modeled hs not found in one of the columns." > /dev/stderr
	error=1
fi
if [ -z "${colSHF}" ]; then
	echo "energybalancecheck.sh: ERROR: sensible heat flux (SHF) not found in one of the columns." > /dev/stderr
	error=1
fi
if [ -z "${colLHF}" ]; then
	echo "energybalancecheck.sh: ERROR: latent heat flux (LHF) not found in one of the columns." > /dev/stderr
	error=1
fi
if [ -z "${colOLWR}" ]; then
	echo "energybalancecheck.sh: ERROR: OLWR not found in one of the columns." > /dev/stderr
	error=1
fi
if [ -z "${colILWR}" ]; then
	echo "energybalancecheck.sh: ERROR: ILWR not found in one of the columns." > /dev/stderr
	error=1
fi
if [ -z "${colNetLWR}" ]; then
	echo "energybalancecheck.sh: ERROR: Net_LWR not found in one of the columns." > /dev/stderr
	error=1
fi
if [ -z "${colRSWR}" ]; then
	echo "energybalancecheck.sh: ERROR: RSWR not found in one of the columns." > /dev/stderr
	error=1
fi
if [ -z "${colISWR}" ]; then
	echo "energybalancecheck.sh: ERROR: ISWR not found in one of the columns." > /dev/stderr
	error=1
fi
if [ -z "${colsoilheat}" ]; then
	echo "energybalancecheck.sh: ERROR: soil heat flux not found in one of the columns." > /dev/stderr
	error=1
fi
if [ -z "${colRainNRG}" ]; then
	echo "energybalancecheck.sh: ERROR: rain energy not found in one of the columns." > /dev/stderr
	error=1
fi
if [ -z "${colIntNRG}" ]; then
	echo "energybalancecheck.sh: ERROR: internal energy change not found in one of the columns." > /dev/stderr
	error=1
fi
if [ -z "${colPhchEnergy}" ]; then
	echo "energybalancecheck.sh: ERROR: phase change energy not found in one of the columns." > /dev/stderr
	error=1
fi
if [ "${error}" -eq 1 ]; then
	exit
fi

# -- Determine file resolution
if (( ${met} )); then
	nsamplesperday=$(cat ${met_file} | sed '1,/\[DATA\]/d' | awk -F, '{print $'${coldatetime}'}' | awk '{print $1}' | sort | uniq -c | awk '{print $1}' | sort -nu | tail -1)
elif (( ${smet} )); then
	nsamplesperday=$(cat ${smet_file} | sed '1,/\[DATA\]/d' | awk -F, '{print substr($'${coldatetime}', 1, 10)}' | awk '{print $1}' | sort | uniq -c | awk '{print $1}' | sort -nu | tail -1)
fi
if [ -z "${nsamplesperday}" ]; then
	echo "energybalancecheck.sh: ERROR: file resolution could not be determined." > /dev/stderr
	exit
fi


# Create header
echo "#Date time measured_HS modelled_HS SHF     LHF    OLWR   ILWR_absorb   RSWR   ISWR   SoilHeatFlux RainEnergy PhaseChangeEnergy deltaIntEnergy EnergyBalance energy_in energy_out"
echo "#--   --   --          --          E+      E+     E+     E+            E+     E+     E+           E+         --                E-             error         totals    totals"
echo "#-    -    cm          cm          W_m-2   W_m-2  W_m-2  W_m-2         W_m-2  W_m-2  W_m-2        W_m-2      W_m-2             W_m-2          W_m-2         W_m-2     W_m-2"


# Process data (note that the lines below are all piped together).
#  -- Cut out data
sed '1,/\[DATA\]/d' ${file} | \
#  -- Select all the energybalance terms, make them correct sign and correct units. Also makes sure some terms are only considered when they are a part of the SNOW energy balance (like SHF, which may also originate from soil).
#     Note: some terms need a change of sign, others need to be converted from kJ/m^2 to W/m^2 and one needs an extra term to be added.
#     Note we store the previous modeled HS, to know whether e.g. SHF was actually from soil or from snow. For the first time step it doesn't matter what we do here, as we will cut out this first line later.
#         (We cannot cut out this first line here, as the previous time step modeled HS is also needed for the energy balance calculations).
awk -F"${field_sep}" -v met=${met} '{n++; if(n==1) {prevHS=1}; ILWR=($'${colhsmodel}'>0.0)?($'${colOLWR}')+($'${colNetLWR}'):0; print $'${coldatetime}', $'${colhsmeasured}', $'${colhsmodel}', ($'${colhsmodel}'>0.0)?($'${colSHF}'):0, ($'${colhsmodel}'>0.0)?($'${colLHF}'):0, ($'${colhsmodel}'>0.0)?-1.0*($'${colOLWR}'):0, ($'${colhsmodel}'>0.0)?(ILWR):0, ($'${colhsmodel}'>0.0)?-1.0*($'${colRSWR}'):0, ($'${colhsmodel}'>0.0)?($'${colISWR}'):0, ($'${colhsmodel}'>0.0)?($'${colsoilheat}'):0, ($'${colhsmodel}'>0.0)?($'${colRainNRG}'):0, ($'${colhsmodel}'>0.0)?($'${colPhchEnergy}'*(1000.0/((24.0/'${nsamplesperday}')*3600))):0, ($'${colhsmodel}'>0.0 && $'${colIntNRG}'!=-999.0)?(1000.0*$'${colIntNRG}'/((24.0/'${nsamplesperday}')*3600)+met*$'${colsoilheat}'):0; prevHS=$'${colhsmodel}'}' | \
#  -- Reformat time
awk -v met=${met} '{if(met) {printf "%04d%02d%02d %02d%02d", substr($1,7,4), substr($1,4,2), substr($1,1,2), substr($2,1,2), substr($2,4,2); for(i=3; i<=NF; i++) {printf " %s", $i}} else {printf "%04d%02d%02d %02d%02d", substr($1,1,4), substr($1,6,2), substr($1,9,2), substr($1,12,2), substr($1,15,2); for(i=2; i<=NF; i++) {printf " %s", $i}}; printf "\n"}' | \
# Now select period
awk '($1>='${firstdate}' && $1<='${lastdate}') {print $0}' | \
#  -- Now do all the other calculations
#     except for the first line (for the first line, we cannot determine the energy balance, as the previous value of modeled HS is unknown, so we don't know whether there was a snowpack).
awk '{n++; if(n>1) \
	#Determine energy balance error:
	energybalance=$5+$6+$7+$8+$9+$10+$11+$12-$14; \
	#Determine energy input in system (taking the terms only when they are positive)
	energy_in=(($5>0.0)?$5:0)+(($6>0.0)?$6:0)+(($7>0.0)?$7:0)+(($8>0.0)?$8:0)+(($9>0.0)?$9:0)+(($10>0.0)?$10:0)+(($11>0.0)?$11:0)+(($12>0.0)?$12:0); \
	#Determine energy output in system (taking the terms only when they are negative)
	energy_out=(($5<0.0)?$5:0)+(($6<0.0)?$6:0)+(($7<0.0)?$7:0)+(($8<0.0)?$8:0)+(($9<0.0)?$9:0)+(($10<0.0)?$10:0)+(($11<0.0)?$11:0)+(($12<0.0)?$12:0); \
	#Do the statistics (energy balance error sum, min and max values)
	ndatapoints++; energybalancesum+=energybalance; energybalancesum2+=sqrt(energybalance*energybalance); incomingsum+=energy_in; if(energybalance>maxenergybalance){maxenergybalance=energybalance; maxenergybalancedate=$1; maxenergybalancetime=$2}; if(energybalance<minenergybalance){minenergybalance=energybalance; minenergybalancedate=$1; minenergybalancetime=$2}; \
	#Write to stdout
	print $0, energybalance, energy_in, energy_out}; \
#Write out statistics to stderr:
END {printf "Summary of file: '${file}'\n-------------------------------------------------------------------------------------\nSum of energy balance error (W_m-2): %.6f (time averaged (W_m-2): %.6f [= %.6f%% from incoming energy])\nSum of absolute energy balance error (W_m-2): %.6f (time averaged (W_m-2): %.6f [= %.6f%% from incoming energy])\nMaximum positive energy balance error (W_m-2): %.6f (= %.0f J_m-2) at %08d, %04d\nMinimum negative energy balance error (W_m-2): %.6f (= %.0f J_m-2) at %08d, %04d\n", energybalancesum, (energybalancesum/ndatapoints), energybalancesum/incomingsum*100.0, energybalancesum2, (energybalancesum2/ndatapoints), energybalancesum2/incomingsum*100.0, maxenergybalance, maxenergybalance*(86400/'${nsamplesperday}'), maxenergybalancedate, maxenergybalancetime, minenergybalance, minenergybalance*(86400/'${nsamplesperday}'), minenergybalancedate, minenergybalancetime > "/dev/stderr"}'

