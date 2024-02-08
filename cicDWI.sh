#! /bin/bash

# zklsmr
# to preprocess CIC ex-vivo DWI, 30 dir 3T protocol
#
if [ $# -eq 2 ]; then
    input_list=$1
    output_path=$2
else
  echo "Usage $0 <input_list> <output_path>"
  echo "Outputs will be saved in <output_path> folder"
  exit 1
fi




## NAMING ###
#
#
#
#
#
#
#





### Pr-processing the native data ###
for i in $(cat ${input_list}); do 
  id=$(echo ${i}|cut -d , -f 1)
  visit=$(echo ${i}|cut -d , -f 2)
  b0_pe=$(echo ${i}|cut -d , -f 3)
  b0_rpe=$(echo ${i}|cut -d , -f 4)
  dwi_vols=$(echo ${i}|cut -d , -f 5)
  dwi_bvec=$(echo ${i}|cut -d , -f 6)
  dwi_bval=$(echo ${i}|cut -d , -f 7)
  echo ${id} ${visit} ${hemisphere}




mkdir -p ${output_path}/${id}/${visit}/misc 

### concatenating ###
mrconvert ${dwi_vols} ${output_path}/${id}/${visit}/misc/${id}_${visit}_dwi_concat.mif -fslgrad ${dwi_bvec} ${dwi_bval}


