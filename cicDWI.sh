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
  mask=$(echo ${i}|cut -d , -f 8)
  echo ${id} ${visit} ${hemisphere}




mkdir -p ${output_path}/${id}/${visit}/dwi
mkdir -p ${output_path}/${id}/${visit}/dti

### Extract WM from mask ###
fslmath ${mask} -thr 7.9 -uthr 8.1 -bin ${output_path}/${id}/${visit}/dwi/WM_mask_bin.nii.gz 
itk_resample --like ${b0_pe} --labels ${output_path}/${id}/${visit}/dwi/WM_mask_bin.nii.gz ${output_path}/${id}/${visit}/dwi/WM_mask_bin_resampled.nii.gz
wm_mask= ${output_path}/${id}/${visit}/dwi/WM_mask_bin_resampled.nii.gz


### Concatenating ###
mrconvert ${dwi_vols} ${output_path}/${id}/${visit}/dwi/${id}_${visit}_dwi_concat.mif -fslgrad ${dwi_bvec} ${dwi_bval}


pe_dir=$(echo "$b0_pe" | awk -F '_' '{print $12}')
rpe_dir=$(echo "$b0_rpe" | awk -F '_' '{print $12}')
mrcat ${b0_pe} ${b0_rpe} ${output_path}/${id}/${visit}/dwi/${id}_${visit}_Bzero_${pe_dir}${rpe_dir}.nii.gz

### Denoising ###
dwidenoise -mask ${wm_mask} ${output_path}/${id}/${visit}/dwi/${id}_${visit}_dwi_concat.mif ${output_path}/${id}/${visit}/dwi/${id}_${visit}_dwi_concat_den.mif

### Unringing
mrdeggibs ${output_path}/${id}/${visit}/dwi/${id}_${visit}_dwi_concat_den.mif ${output_path}/${id}/${visit}/dwi/${id}_${visit}_dwi_concat_den_unr.mif


### Eddy and Topup ###
dwifslpreproc ${output_path}/${id}/${visit}/dwi/${id}_${visit}_dwi_concat_den_unr.mif ${output_path}/${id}/${visit}/dwi/${id}_${visit}_dwi_concat_den_unr_preproc.mif -pe_dir ${pe_dir} -readout_time 0.064 -rpe_pair -se_epi ${output_path}/${id}/${visit}/dwi/${id}_${visit}_Bzero_${pe_dir}${rpe_dir}.nii.gz -eddy_mask ${wm_mask} -eddy_options " --slm=linear --flm=quadratic --repol"

### ANTs N4 Unbias ###
dwibiascorrect ants ${output_path}/${id}/${visit}/dwi/${id}_${visit}_dwi_concat_den_unr_preproc.mif ${output_path}/${id}/${visit}/dwi/${id}_${visit}_dwi_concat_den_unr_preproc_unb.mif -mask ${wm_mask}

### Compute Tensor ###
dwi2tensor -mask ${wm_mask} ${output_path}/${id}/${visit}/dwi/${id}_${visit}_dwi_concat_den_unr_preproc_unb.mif ${output_path}/${id}/${visit}/dti/${id}_${visit}_dwi_concat_den_unr_preproc_unb_DTensor.mif


### Compute tensor metrics ###
tensor2metric -mask ${wm_mask} -fa ${output_path}/${id}/${visit}/dti/${id}_${visit}_fa.nii -adc ${output_path}/${id}/${visit}/dti/${id}_${visit}_md.nii -rd ${output_path}/${id}/${visit}/dti/${id}_${visit}_rd.nii -ad ${output_path}/${id}/${visit}/dti/${id}_${visit}_ad.nii ${output_path}/${id}/${visit}/dti/${id}_${visit}_dwi_concat_den_unr_preproc_unb_DTensor.mif

