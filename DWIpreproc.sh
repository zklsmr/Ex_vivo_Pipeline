#DWI preprocessing and DTI computation script
#Zaki Alasmar (zklsmr) - Dec 07 2023
#TODO: plenty of things, not totally happy with it

#!/bin/bash

src_raw="SOMEPATH/niix_Files/"
out_raw="SOMEOTHERPATH/all_subs/raw_diff/"

src_mask="ANOTHERPATH/BISON_Native/"
out_dti="SOMEOTHERPATH/all_subs/proc/"

previous_DTI="MOREPATHS/diff_data/"
my_src_raw="JUSTABACKUPPATH/diff_data_raw_backup/"

for sub_mask in "$src_mask"/*; do

	# Get subject ID & session date
	sub_id=$(basename "$sub_mask" | cut -d '_' -f 1)
	sub_sess_date=$(basename "$sub_mask" | cut -d '_' -f 2)
	echo "$sub_id   ----->   "

	# Identify a path for preprocessed date, and check if it has FA maps
	checking=($(ls "$previous_DTI$sub_id"/tensor*/FA.nii* 2>/dev/null))

	if [ ${#checking[@]} -gt 0 ]; then
		echo "Subject has already been preprocessed"
		echo "---------------------------------------------------------------------------------------------"
	else
		echo "New subject"

		# Check the subject raw directory in dadmah exists
		sub_dir=($(ls -d "$my_src_raw"*"DH${sub_id#DH}"* 2>/dev/null))

		if [ ${#sub_dir[@]} -ge 1 ]; then
			echo "Subject Dir = $(
				test -d "${sub_dir[0]}"
				echo $?
			)   ----->   "

			# If the directory exists, check that a diffusion image exists
			diff_dwi_image=($(ls "${sub_dir[0]}"/*DWI_sag*nii 2>/dev/null))

			# If not, stop
			if [ ${#diff_dwi_image[@]} -eq 0 ]; then
				echo -e "\n-=-=-=--=-=-=--=-=-=--=-=-=--=-=-=--=-=-=--=-=-=--=-=-=-"
				echo "${diff_dwi_image[@]} No DWI volume"
				echo "-=-=-=--=-=-=--=-=-=--=-=-=--=-=-=--=-=-=--=-=-=--=-=-=-"
			else
				echo "DWI image =  $(
					test -f "${diff_dwi_image[0]}"
					echo $?
				)   ----->   "

				# Check if the subject has B0 images
				b0_images=($(ls "${sub_dir[0]}"/*B0*nii 2>/dev/null))

				# There should be two B0 images in opposite encoding directions
				if [ ${#b0_images[@]} -eq 2 ]; then
					# Get the paths for the AP or RL
					b0_images_encDWI=($(ls "${sub_dir[0]}"/*DWI-B0_*nii 2>/dev/null))
					b0_images_encDWI_INV=($(ls "${sub_dir[0]}"/*DWI-B03_*nii 2>/dev/null))

					echo "B0 images = True   ----->   "

					# Concatenate the two B0 images in the correct way as expected by MRtrix, then output to the raw directory of images
					bzero_out_dir="$my_src_raw$sub_id"
					bzero_concat_cmd=("mrcat" "-axis" "3" "${b0_images_encDWI[0]}" "${b0_images_encDWI_INV[0]}" "${bzero_out_dir}/Bzero_${b0_images_encDWI[0]##*/sag_??}${b0_images_encDWI_INV[0]##*/sag_??}.mif")
					"${bzero_concat_cmd[@]}"

					# Convert the mask to nii and output it to the subject's raw directory along with their DWI images
					mask_minc2nii_cmd=("mnc2nii" "${sub_mask}" "${my_src_raw}${sub_id}/${sub_mask%.*}.nii")
					"${mask_minc2nii_cmd[@]}"

					# From the nii mask that we just converted, create separate binary masks for the GM, WM, and subcortex, then combine them into one binarized whole brain mask
					fslmath_GM_cmd=("fslmaths" "${my_src_raw}${sub_id}/${sub_mask%.*}.nii" "-thr" "0.9" "-uthr" "1.2" "-bin" "${my_src_raw}${sub_id}/${sub_mask%.*}_GM_mask.nii.gz")
					"${fslmath_GM_cmd[@]}"

					fslmath_WM_cmd=("fslmaths" "${my_src_raw}${sub_id}/${sub_mask%.*}.nii" "-thr" "8.9" "-uthr" "9.1" "-bin" "${my_src_raw}${sub_id}/${sub_mask%.*}_WM_mask.nii.gz")
					"${fslmath_WM_cmd[@]}"

					fslmath_subcortex_cmd=("fslmaths" "${my_src_raw}${sub_id}/${sub_mask%.*}.nii" "-thr" "1.9" "-uthr" "5.1" "-bin" "${my_src_raw}${sub_id}/${sub_mask%.*}_subcortex_mask.nii.gz")
					"${fslmath_subcortex_cmd[@]}"

					fslmath_brainmask_cmd=("fslmaths" "${my_src_raw}${sub_id}/${sub_mask%.*}_GM_mask.nii.gz" "-add" "${my_src_raw}${sub_id}/${sub_mask%.*}_WM_mask.nii.gz" "-add" "${my_src_raw}${sub_id}/${sub_mask%.*}_subcortex_mask.nii.gz" "${my_src_raw}${sub_id}/${sub_mask%.*}_wholebrain_mask.nii.gz")
					"${fslmath_brainmask_cmd[@]}"

					# =========================================================#
					#               Preprocessing starts here                 #
					# =========================================================#

					# Preprocessing (THIS NEEDS TO BE DONE PROPERLY)

					# Concatenate the DWI images, the b-vectors, and the b-values into one image, then denoise it

					bvals_path=($(ls "${sub_dir[0]}"/*DWI_sag*bval))
					bvecs_path=($(ls "${sub_dir[0]}"/*DWI_sag*bvec))

					if [ "${bvals_path%.*}" == "${diff_dwi_image[0]%.*}" ]; then
						# New basename to save images as
						new_basename="${diff_dwi_image[0]##*/}"

						# Resample the combined brain mask to use in the preprocessing
						itk_resample_cmd=("itk_resample" "${my_src_raw}${sub_id}/${sub_mask%.*}_wholebrain_mask.nii.gz" "--like" "${b0_images_encDWI[0]}" "--labels" "--clobber" "${my_src_raw}${sub_id}/${sub_mask%.*}_wholebrain_mask_resampled.nii.gz")
						"${itk_resample_cmd[@]}"

						concate_bvecvals_cmd=("mrconvert" "${diff_dwi_image[0]}" "${previous_DTI}${sub_id}/denoised_data/${new_basename}_concat.mif" "-fslgrad" "${bvecs_path[0]}" "${bvals_path[0]}")
						"${concate_bvecvals_cmd[@]}"

						concate_bvecvals_denoise_cmd=("dwidenoise" "${previous_DTI}${sub_id}/denoised_data/${new_basename}_concat.mif" "${previous_DTI}${sub_id}/denoised_data/${new_basename}_concat_denoised.mif" "-noise" "${previous_DTI}${sub_id}/denoised_data/${new_basename}_noise.mif" "-mask" "${my_src_raw}${sub_id}/${sub_mask%.*}_wholebrain_mask_resampled.nii.gz")
						"${concate_bvecvals_denoise_cmd[@]}"

						# De-gibbs the concatenated denoised image
						degibbs_cmd=("mrdegibbs" "${previous_DTI}${sub_id}/denoised_data/${new_basename}_concat_denoised.mif" "${previous_DTI}${sub_id}/unrang_data/${new_basename}_concat_denoised_unrang.mif" "-axes" "1,2")
						"${degibbs_cmd[@]}"

						# FSL preprocess the concatenated denoised de-gibbs image
						fslpreproc_cmd=("dwifslpreproc" "${previous_DTI}${sub_id}/unrang_data/${new_basename}_concat_denoised_unrang.mif" "${previous_DTI}${sub_id}/fslpreproc_data/${new_basename}_concat_denoised_unrang_preproc.mif" "-pe_dir" "${b0_images_encDWI[0]##*/sag_??}" "-nthreads" "20" "-eddy_mask" "${my_src_raw}${sub_id}/${sub_mask%.*}_wholebrain_mask_resampled.nii.gz" "-rpe_pair" "-se_epi" "${bzero_out_dir}/Bzero_${b0_images_encDWI[0]##*/sag_??}${b0_images_encDWI_INV[0]##*/sag_??}.mif" "-eddy_options" "--slm=linear")
						"${fslpreproc_cmd[@]}"

						# ANTs bias correction and N3 the concatenated denoised de-gibbs preprocessed image
						bias_cor_cmd=("dwibiascorrect" "fsl" "${previous_DTI}${sub_id}/fslpreproc_data/${new_basename}_concat_denoised_unrang_preproc.mif" "${previous_DTI}${sub_id}/unbias_data/${new_basename}_concat_denoised_unrang_preproc_unbiased.mif" "-bias" "${previous_DTI}${sub_id}/unbias_data/${new_basename}_concat_denoised_unrang_preproc_bias.mif" "-mask" "${my_src_raw}${sub_id}/${sub_mask%.*}_wholebrain_mask_resampled.nii.gz")
						"${bias_cor_cmd[@]}"

						# Compute tensor of the concatenated denoised de-gibbs preprocessed bias-corrected image
						tensor_cmd=("dwi2tensor" "-mask" "${my_src_raw}${sub_id}/${sub_mask%.*}_wholebrain_mask_resampled.nii.gz" "${previous_DTI}${sub_id}/unbias_data/${new_basename}_concat_denoised_unrang_preproc_unbiased.mif" "${previous_DTI}${sub_id}/tensor_data/${new_basename}_concat_denoised_unrang_preproc_unbiased_DTI.nii")
						"${tensor_cmd[@]}"

						# Compute the tensor metrics (FA AD RD MD)
						metrics_cmd=("tensor2metric" "-mask" "${my_src_raw}${sub_id}/${sub_mask%.*}_wholebrain_mask_resampled.nii.gz" "-fa" "${previous_DTI}${sub_id}/tensor_data/${new_basename}_concat_denoised_unrang_preproc_unbiased_DTI_FA.nii" "-ad" "${previous_DTI}${sub_id}/tensor_data/${new_basename}_concat_denoised_unrang_preproc_unbiased_DTI_AD.nii" "-rd" "${previous_DTI}${sub_id}/tensor_data/${new_basename}_concat_denoised_unrang_preproc_unbiased_DTI_RD.nii" "-adc" "${previous_DTI}${sub_id}/tensor_data/${new_basename}_concat_denoised_unrang_preproc_unbiased_DTI_MD.nii" "${previous_DTI}${sub_id}/tensor_data/${new_basename}_concat_denoised_unrang_preproc_unbiased_DTI.nii")
						"${metrics_cmd[@]}"

						echo -e "\n-=-=-=--=-=-=--=-=-=--=-=-=--=-=-=--=-=-=--=-=-=--=-=-=-"
						echo "Finished DTI metric extraction"
						echo -e "\n-=-=-=--=-=-=--=-=-=--=-=-=--=-=-=--=-=-=--=-=-=--=-=-=-"

					fi
				else
					echo "Subject ${sub_id} Does not have DWI data"
				fi
			fi
		fi
		echo -e "\n============================================================================================"
	fi
done
