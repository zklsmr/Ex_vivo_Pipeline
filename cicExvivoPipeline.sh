#! /bin/bash

### Mahsa Dadar , Yashar Zeighami 2023-10-05  ###
#Input file format:
# id,visit,t1,t2
# Dependencies: minc-toolkit, anaconda, and ANTs
# for use at the CIC, you can load the following modules (or similar versions)
# module load minc-toolkit-v2/1.9.18.2 ANTs/20220513 anaconda/2022.05

if [ $# -eq 3 ];then
    input_list=$1
    model_path=$2
    output_path=$3
else
 echo "Usage $0 <input list> <model path> <output_path>"
 echo "Outputs will be saved in <output_path> folder"
 exit 1
fi

### Naming Conventions ###
# stx: stereotaxic space (i.e. registered to the standard template)
# lin: linear registration 
# nlin: nonlinear registration
# dbm: deformation based morphometry
# cls: tissue classification
# qc: quality control
# tmp: temporary
# nlm: denoised file (Coupe et al. 2008)
# n3: non-uniformity corrected file (Sled et al. 1998)
# vp: acronym for volume_pol, intensity normalized file
# t1: T1 weighted image 
# t2: T2 weighted image
# icbm: standard template
# beast: acronym for brain extraction based on nonlocal segmentation technique (Eskildsen et al. 2012)
# ANTs: Advanced normalization tools (Avants et al. 2009)
# BISON: Brain tissue segmentation (Dadar et al. 2020)

### Pre-processing the native data ###
for i in $(cat ${input_list});do
    id=$(echo ${i}|cut -d , -f 1)
    visit=$(echo ${i}|cut -d , -f 2)
    t1=$(echo ${i}|cut -d , -f 3)
    t2=$(echo ${i}|cut -d , -f 4)
    hemisphere=$(echo ${i}|cut -d , -f 5)
    echo ${id} ${visit} ${hemisphere}
    ### Creating the directories for preprocessed outputs ###
    # native: where the preprocessed images (denoising, non-uniformity correction, intensity normalization) will be saved (before linear registration)
    # stx_lin: where the preprocessed and linearly registered images will be saved
    # stx_nlin: where nonlinear registration outputs (ANTs) will be saved
    # vbm: where deformation based morphometry (dbm) outputs will be saved
    # cls: where tissue classficiation outputs (BISON) will be saved 
    # template: where linear and nonlinear average template will be saved
    # qc: where quality control images will be saved
    # tmp: temporary files, will be deleted at the end

    mkdir -p ${output_path}/${id}/${visit}/native
    mkdir -p ${output_path}/${id}/${visit}/stx_lin
    mkdir -p ${output_path}/${id}/${visit}/stx_nlin
    mkdir -p ${output_path}/${id}/${visit}/vbm
    mkdir -p ${output_path}/${id}/${visit}/cls
    mkdir -p ${output_path}/${id}/template
    mkdir -p ${output_path}/${id}/qc
    mkdir -p ${output_path}/${id}/tmp

    ### denoising ###
    mincnlm ${t1} ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_nlm.mnc -mt 1 -beta 0.7 -clobber
    if [ ! -z ${t2} ];then mincnlm ${t2} ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_nlm.mnc -mt 1 -beta 0.7 -clobber; fi

    ### co-registration of different modalities to t1 ###
    if [ ! -z ${t2} ];then bestlinreg_s2 -lsq6 ${t2} ${t1} ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_to_t1.xfm -clobber -mi; fi

    ## generating temporary masks for non-uniformity correction ###

    if [ ${hemisphere} = "L" ];then
        echo Left Brain Hemisphere
        mincresample ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_nlm.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_nlm_reorient.mnc -like ${model_path}/Av_T1.mnc \
        -transform ${model_path}/manual_l.xfm -clobber
        bestlinreg_s2 ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_nlm_reorient.mnc ${model_path}/Av_T1.mnc -target_mask ${model_path}/mask_left.mnc\
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp0.xfm  -clobber
        xfmconcat ${model_path}/manual_l.xfm  ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp0.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm -clobber
        if [ ! -z ${t2} ];then xfmconcat ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_to_t1.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm \
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_to_icbm_stx_tmp.xfm -clobber; fi

        mincresample  ${model_path}/mask_left.mnc -like ${t1} ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_mask_tmp.mnc -transform \
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm -inv -nearest -clobber
        if [ ! -z ${t2} ];then mincresample  ${model_path}/mask_left.mnc -like ${t2} ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_mask_tmp.mnc -transform \
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_to_icbm_stx_tmp.xfm  -inv -nearest -clobber; fi
    fi

    if [ ${hemisphere} = "R" ];then
        echo Right Brain Hemisphere
        mincresample ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_nlm.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_nlm_reorient.mnc -like ${model_path}/Av_T1.mnc \
        -transform ${model_path}/manual_r.xfm -clobber
        bestlinreg_s2 ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_nlm_reorient.mnc ${model_path}/Av_T1.mnc -target_mask ${model_path}/mask_right.mnc \
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp0.xfm -clobber
        xfmconcat ${model_path}/manual_r.xfm   ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp0.xfm   ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm -clobber
        if [ ! -z ${t2} ];then xfmconcat ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_to_t1.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm \
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_to_icbm_stx_tmp.xfm -clobber; fi

        mincresample  ${model_path}/mask_right.mnc -like ${t1} ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_mask_tmp.mnc -transform \
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm -inv -nearest -clobber
        if [ ! -z ${t2} ];then mincresample  ${model_path}/mask_right.mnc -like ${t2} ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_mask_tmp.mnc -transform \
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_to_icbm_stx_tmp.xfm  -inv -nearest -clobber; fi
    fi
  
    ### non-uniformity correction ###
    nu_correct ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_nlm.mnc ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_n3.mnc \
     -mask ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_mask_tmp.mnc -iter 200 -distance 200 -stop 0.000001 -normalize_field  -clobber
    if [ ! -z ${t2} ];then nu_correct ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_nlm.mnc ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_n3.mnc \
    -mask ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_mask_tmp.mnc -iter 200 -distance 200 -stop 0.000001 -normalize_field  -clobber; fi

    ### intensity normalization ###
    volume_pol ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_n3.mnc ${model_path}/Av_T1.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc \
     --source_mask ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_mask_tmp.mnc --target_mask ${model_path}/Mask.mnc  --clobber
    if [ ! -z ${t2} ];then volume_pol ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_n3.mnc ${model_path}/Av_T2.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_vp.mnc \
     --source_mask ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_mask_tmp.mnc --target_mask ${model_path}/Mask.mnc  --clobber; fi

    ### registering everything to stx space ###
    if [ ! -z ${t2} ];then bestlinreg_g -mi -lsq6 ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_vp.mnc ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc \
    ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_to_t1.xfm -clobber; fi

done

tp=$(cat ${input_list}|wc -l)
### for just one timepoint; i.e. cross-sectional data ###
if [ ${tp} = 1 ];then 
    if [ ${hemisphere} = "L" ];then
        mincresample ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_nlm_reorient.mnc -like ${model_path}/Av_T1.mnc \
        -transform ${model_path}/manual_l.xfm -clobber
        bestlinreg_s2 ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_nlm_reorient.mnc ${model_path}/Av_T1.mnc -target_mask ${model_path}/mask_left.mnc\
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp0.xfm  -clobber
        xfmconcat ${model_path}/manual_l.xfm   ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp0.xfm  ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm.xfm
    fi

    if [ ${hemisphere} = "R" ];then
        mincresample ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_nlm_reorient.mnc -like ${model_path}/Av_T1.mnc \
        -transform ${model_path}/manual_r.xfm -clobber
        bestlinreg_s2 ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_nlm_reorient.mnc ${model_path}/Av_T1.mnc -target_mask ${model_path}/mask_right.mnc \
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp0.xfm -clobber
        xfmconcat ${model_path}/manual_r.xfm  ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp0.xfm  ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm.xfm
    fi

    if [ ! -z ${t2} ];then xfmconcat ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_to_t1.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm.xfm  \
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_to_icbm_stx2.xfm; fi

    itk_resample ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin.mnc \
    --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm.xfm --order 4 --clobber
    if [ ! -z ${t2} ];then itk_resample ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_vp.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_stx2_lin.mnc \
    --like ${model_path}/Av_T2.mnc --transform ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_to_icbm_stx2.xfm --order 4 --clobber; fi

    itk_resample ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin_lowres.mnc \
    --like ${model_path}/lowres.mnc --transform ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm.xfm --order 4 --clobber
    mincbeast ${model_path}/ADNI_library ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin_lowres.mnc \
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask_lowres.mnc -fill -median -same_resolution \
    -configuration ${model_path}/ADNI_library/default.2mm.conf -clobber
     
    mincresample ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask_lowres.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask_tmp.mnc -nearest -like \
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin.mnc -clobber

    if [ ${hemisphere} = "L" ];then
        minccalc -expression 'A[0]*A[1]' ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask_tmp.mnc ${model_path}/left.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc
    fi
    if [ ${hemisphere} = "R" ];then
        minccalc -expression 'A[0]*A[1]' ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask_tmp.mnc ${model_path}/right.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc
    fi

    volume_pol ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin.mnc ${model_path}/Av_T1.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp \
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin_vp.mnc  --source_mask ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc \
    --target_mask ${model_path}/Mask.mnc --clobber
    if [ ! -z ${t2} ];then volume_pol ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_stx2_lin.mnc ${model_path}/Av_T2.mnc --order 1 --noclamp \
    --expfile ${output_path}/${id}/tmp/tmp ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_stx2_lin_vp.mnc  --source_mask ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc \
    --target_mask ${model_path}/Mask.mnc --clobber; fi

    if [ ${hemisphere} = "L" ];then
        trg_mask=${model_path}/mask_left.mnc    
    fi
    if [ ${hemisphere} = "R" ];then
        trg_mask=${model_path}/mask_right.mnc    
    fi

    src=${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin_vp.mnc
    trg=${model_path}/Av_T1.mnc
    src_mask=${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc
    
    outp=${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_inv_nlin_
    if [ ! -z $trg_mask ];then
        mask="-x [${src_mask},${trg_mask}] "
    fi
    antsRegistration -v -d 3 --float 1  --output "[${outp}]"  --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
    --transform "SyN[0.7,3,0]" --metric "CC[${src},${trg},1,4]" --convergence "[50x50x30,1e-6,10]" --shrink-factors 4x2x1 --smoothing-sigmas 2x1x0vox ${mask} --minc

    itk_resample ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin_vp.mnc ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_nlin.mnc \
            --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_inv_nlin_0_inverse_NL.xfm --order 4 --clobber --invert_transform
    grid_proc --det ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_inv_nlin_0_inverse_NL_grid_0.mnc ${output_path}/${id}/${visit}/vbm/${id}_${visit}_dbm.mnc
    
    echo Subjects,T1s,Masks,XFMs >> ${output_path}/${id}/to_segment_t1.csv
    echo ${id}_${visit}_t1,${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin.mnc,\
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc,\
    ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_inv_nlin_0_inverse_NL.xfm >> ${output_path}/${id}/to_segment_t1.csv 
fi
tp=$(cat ${input_list}|wc -l)
### for longitudinal data: initial rigid registration of timepoints ###
if [ ${tp} -gt 1 ];then
    for timepoint in $(seq 1 ${tp});do
        tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
        id=$(echo ${tmp}|cut -d , -f 1)
        visit_tp=$(echo ${tmp}|cut -d , -f 2)
        if [ ${timepoint} = 1 ];then 
            if [ ${hemisphere} = "L" ];then
                echo Right Brain Hemisphere
                mincresample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_nlm_reorient.mnc -like ${model_path}/Av_T1.mnc \
                -transform ${model_path}/manual_l.xfm -clobber
                bestlinreg_s2 ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_nlm_reorient.mnc ${model_path}/Av_T1.mnc -target_mask ${model_path}/mask_left.mnc\
                ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_to_icbm_stx_tmp0.xfm 
                xfmconcat ${model_path}/manual_l.xfm   ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_to_icbm_stx_tmp0.xfm  ${output_path}/${id}/template/${id}_baseline_to_icbm_stx.xfm -clobber 
            fi

            if [ ${hemisphere} = "R" ];then
                echo Right Brain Hemisphere
                mincresample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_nlm_reorient.mnc -like ${model_path}/Av_T1.mnc \
                -transform ${model_path}/manual_r.xfm -clobber
                bestlinreg_s2 ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_nlm_reorient.mnc ${model_path}/Av_T1.mnc -target_mask ${model_path}/mask_right.mnc \
                ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_to_icbm_stx_tmp0.xfm 
                xfmconcat ${model_path}/manual_r.xfm ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_to_icbm_stx_tmp0.xfm  ${output_path}/${id}/template/${id}_baseline_to_icbm_stx.xfm -clobber 
            fi
            cp ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${output_path}/${id}/template/${id}_baseline.mnc
            cp ${model_path}/i.xfm  ${output_path}/${id}/template/${id}_${visit_tp}_to_baseline.xfm
            itk_resample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${output_path}/${id}/template/${id}_${visit_tp}_0.mnc \
            --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/template/${id}_baseline_to_icbm_stx.xfm --order 4 --clobber
        fi
        if [ ${timepoint} -gt 1 ];then 
            bestlinreg_g -lsq6 ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${output_path}/${id}/template/${id}_baseline.mnc \
            ${output_path}/${id}/template/${id}_${visit_tp}_to_baseline.xfm -clobber
            xfmconcat ${output_path}/${id}/template/${id}_${visit_tp}_to_baseline.xfm  ${output_path}/${id}/template/${id}_baseline_to_icbm_stx.xfm \
            ${output_path}/${id}/template/${id}_${visit_tp}_to_icbm.xfm
            itk_resample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${output_path}/${id}/template/${id}_${visit_tp}_0.mnc \
            --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/template/${id}_${visit_tp}_to_icbm.xfm --order 4 --clobber
        fi
    done
    mincaverage ${output_path}/${id}/template/${id}_*_0.mnc ${output_path}/${id}/template/${id}_lin_av.mnc -clobber
fi
tp=$(cat ${input_list}|wc -l)
### for longitudinal data: linear average template ###
if [ ${tp} -gt 1 ];then
    for iteration in {1..5};do
        for timepoint in $(seq 1 ${tp});do
            tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
            id=$(echo ${tmp}|cut -d , -f 1)
            visit_tp=$(echo ${tmp}|cut -d , -f 2)
            bestlinreg_g ${output_path}/${id}/template/${id}_${visit_tp}_0.mnc ${output_path}/${id}/template/${id}_lin_av.mnc ${output_path}/${id}/template/${id}_${visit_tp}.xfm -lsq6 -clobber
            xfmconcat ${output_path}/${id}/template/${id}_${visit_tp}_to_baseline.xfm  ${output_path}/${id}/template/${id}_baseline_to_icbm_stx.xfm \
            ${output_path}/${id}/template/${id}_${visit_tp}.xfm ${output_path}/${id}/template/${id}_${visit_tp}_to_icbm.xfm -clobber
            itk_resample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${output_path}/${id}/template/${id}_${visit_tp}_0.mnc \
            --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/template/${id}_${visit_tp}_to_icbm.xfm --order 4 --clobber
        done
        mincaverage ${output_path}/${id}/template/${id}_*_0.mnc ${output_path}/${id}/template/${id}_lin_av.mnc -clobber
    done

    bestlinreg_g ${output_path}/${id}/template/${id}_lin_av.mnc ${model_path}/Av_T1.mnc ${output_path}/${id}/template/${id}_lin_av_to_template.xfm  -clobber
    for timepoint in $(seq 1 ${tp});do
        tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
        id=$(echo ${tmp}|cut -d , -f 1)
        visit_tp=$(echo ${tmp}|cut -d , -f 2)
        itk_resample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc \
        --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/template/${id}_${visit_tp}_to_icbm.xfm --order 4 --clobber
        cp ${output_path}/${id}/template/${id}_${visit_tp}_to_icbm.xfm ${output_path}/${id}/${visit_tp}/stx_lin/
        if [ ! -z ${t2} ];then xfmconcat ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t2_to_t1.xfm ${output_path}/${id}/template/${id}_${visit_tp}_to_icbm.xfm \
         ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_to_icbm_stx.xfm; fi

        if [ ! -z ${t2} ];then itk_resample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t2_vp.mnc ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_stx2_lin.mnc \
        --like ${model_path}/Av_T2.mnc --transform ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_to_icbm_stx.xfm --order 4 --clobber; fi
        ### BEaST brain mask + another round of intensity normalization with the BEaST mask### 
        mincbeast ${model_path}/ADNI_library ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc \
        ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc -fill -median -same_resolution -configuration \
        ${model_path}/ADNI_library/default.2mm.conf -clobber
        ### Second round of intensity normalization with the refined brain mask ###
        volume_pol ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc ${model_path}/Av_T1.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp \
        ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc  --source_mask ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc --target_mask ${model_path}/Mask.mnc --clobber
        if [ ! -z ${t2} ];then volume_pol ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_stx2_lin.mnc ${model_path}/Av_T2.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp \
        ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_stx2_lin_vp.mnc  --source_mask ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc --target_mask ${model_path}/Mask.mnc --clobber; fi
    done
fi

### for longitudinal data: nonlinear average template ###
tp=$(cat ${input_list}|wc -l)
if [ ${tp} -gt 1 ];then 
    cp ${output_path}/${id}/template/${id}_lin_av.mnc  ${output_path}/${id}/template/${id}_nlin_av.mnc 
    mincbeast ${model_path}/ADNI_library ${output_path}/${id}/template/${id}_nlin_av.mnc ${output_path}/${id}/template/${id}_mask.mnc \
    -fill -median -same_resolution -configuration ${model_path}/ADNI_library/default.2mm.conf -clobber
    for iteration in {1..4};do
        for timepoint in $(seq 1 ${tp});do
            tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
            visit_tp=$(echo ${tmp}|cut -d , -f 2)
            src=${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc
            trg=${output_path}/${id}/template/${id}_nlin_av.mnc
            src_mask=${output_path}/${id}/template/${id}_mask.mnc
            trg_mask=${output_path}/${id}/template/${id}_mask.mnc
            outp=${output_path}/${id}/template/${id}_${visit_tp}_nl_ants_

            if [ ! -z $trg_mask ];then
                mask="-x [${src_mask},${trg_mask}] "
            fi

            if [ ${iteration} = 1 ];then 
                antsRegistration -v -d 3 --float 1  --output "[${outp}]"  --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
                --transform "SyN[0.7,3,0]" --metric "CC[${src},${trg},1,4]" --convergence "[500x500x300,1e-6,10]" --shrink-factors 32x16x8 --smoothing-sigmas 16x8x4vox ${mask} --minc
            fi
            if [ ${iteration} = 2 ];then 
                antsRegistration -v -d 3 --float 1  --output "[${outp}]"  --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
                --transform "SyN[0.7,3,0]" --metric "CC[${src},${trg},1,4]" --convergence "[250x250x150,1e-6,10]" --shrink-factors 16x8x4 --smoothing-sigmas 8x4x2vox ${mask} --minc
            fi
            if [ ${iteration} = 3 ];then 
                antsRegistration -v -d 3 --float 1  --output "[${outp}]"  --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
                --transform "SyN[0.7,3,0]" --metric "CC[${src},${trg},1,4]" --convergence "[100x100x50,1e-6,10]" --shrink-factors 8x4x2 --smoothing-sigmas 4x2x1vox ${mask} --minc
            fi
            if [ ${iteration} = 4 ];then 
                antsRegistration -v -d 3 --float 1  --output "[${outp}]"  --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
                --transform "SyN[0.7,3,0]" --metric "CC[${src},${trg},1,4]" --convergence "[50x50x30,1e-6,10]" --shrink-factors 4x2x1 --smoothing-sigmas 2x1x0vox ${mask} --minc
            fi
            itk_resample ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc ${output_path}/${id}/template/${id}_${visit_tp}_nlin.mnc \
            --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/template/${id}_${visit_tp}_nl_ants_0_inverse_NL.xfm --order 4 --clobber --invert_transform
        done
        mincaverage ${output_path}/${id}/template/*_nlin.mnc ${output_path}/${id}/template/${id}_nlin_av.mnc -clobber
    done

### nonlinear registration of nonlinear subject specific template to reference template###
src=${output_path}/${id}/template/${id}_nlin_av.mnc
trg=${model_path}/Av_T1.mnc
src_mask=${output_path}/${id}/template/${id}_mask.mnc
trg_mask=${model_path}/Mask.mnc
outp=${output_path}/${id}/template/${id}_nlin_av_to_ref_nl_ants_
if [ ! -z $trg_mask ];then
    mask="-x [${src_mask},${trg_mask}] "
fi
antsRegistration -v -d 3 --float 1  --output "[${outp}]"  --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
--transform "SyN[0.7,3,0]" --metric "CC[${src},${trg},1,4]" --convergence "[50x50x30,1e-6,10]" --shrink-factors 4x2x1 --smoothing-sigmas 2x1x0vox ${mask} --minc
itk_resample ${output_path}/${id}/template/${id}_nlin_av.mnc ${output_path}/${id}/template/${id}_nlin_av_to_icbm.mnc \
--like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/template/${id}_nlin_av_to_ref_nl_ants_0_inverse_NL.xfm --order 4 --clobber --invert_transform
fi
### Deformation-Based Mprphometry (DBM) ###
tp=$(cat ${input_list}|wc -l)
if [ ${tp} -gt 1 ];then 
    for timepoint in $(seq 1 ${tp});do
        tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
        visit_tp=$(echo ${tmp}|cut -d , -f 2)
        xfmconcat ${output_path}/${id}/template/${id}_nlin_av_to_ref_nl_ants_0_inverse_NL.xfm ${output_path}/${id}/template/${id}_${visit_tp}_nl_ants_0_inverse_NL.xfm \
            ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_both_inverse_NL.xfm -clobber
        xfm_normalize.pl ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_both_inverse_NL.xfm ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_NL.xfm \
        --like ${model_path}/Av_T1.mnc --exact --clobber
        itk_resample ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_nlin.mnc \
            --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_NL.xfm --order 4 --clobber --invert_transform
        grid_proc --det ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_NL_grid_0.mnc ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_dbm.mnc
    done
fi

### Running BISON for tissue classification ###
if [ ${tp} -gt 1 ];then 
echo Subjects,T1s,Masks,XFMs >> ${output_path}/${id}/to_segment_t1.csv
for timepoint in $(seq 1 ${tp});do
    tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
    id=$(echo ${tmp}|cut -d , -f 1)
    visit_tp=$(echo ${tmp}|cut -d , -f 2)
    echo ${id}_${visit_tp}_t1,${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc,\
    ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc,\
    ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_NL.xfm >> ${output_path}/${id}/to_segment_t1.csv 
done
fi
python ${model_path}/BISON.py -c RF0 -m ${model_path}/Pretrained_Library_DBCBB_L11/ \
 -o  ${output_path}/${id}/${visit_tp}/cls/ -t ${output_path}/${id}/tmp/ -e PT -n  ${output_path}/${id}/to_segment_t1.csv  -p  ${model_path}/Pretrained_Library_DBCBB_L11/ -l 9

itk_resample ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit}_t1_Label.mnc  ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit}_t1_native_Label.mnc \
--like ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc --transform ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm.xfm --label --invert_transform --clobber

### generating QC files ###
for timepoint in $(seq 1 ${tp});do
    tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
    id=$(echo ${tmp}|cut -d , -f 1)
    visit_tp=$(echo ${tmp}|cut -d , -f 2)
    minc_qc.pl ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc ${output_path}/${id}/qc/${id}_${visit_tp}_t1_stx2_lin_vp.jpg \
     --mask ${model_path}/outline.mnc --big --clobber  --image-range 0 100
    if [ ! -z ${t2} ];then minc_qc.pl ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_stx2_lin_vp.mnc ${output_path}/${id}/qc/${id}_${visit_tp}_t2_stx2_lin_vp.jpg \
     --mask ${model_path}/outline.mnc --big --clobber  --image-range 0 100; fi
        minc_qc.pl ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc ${output_path}/${id}/qc/${id}_${visit_tp}_t1_mask.jpg \
     --mask ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc --big --clobber  --image-range 0 100 
    minc_qc.pl ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_nlin.mnc  ${output_path}/${id}/qc/${id}_${visit_tp}_stx2_nlin.jpg \
     --mask ${model_path}/outline.mnc --big --clobber  --image-range 0 100     
done
mv ${output_path}/${id}/${visit_tp}/cls/*.jpg ${output_path}/${id}/qc/
## removing unnecessary intermediate files ###
rm -rf ${output_path}/${id}/tmp/
rm ${output_path}/${id}/*/*/*tmp.xfm
rm ${output_path}/${id}/*/*/*tmp.mnc
rm ${output_path}/${id}/*/*/*tmp
rm ${output_path}/${id}/*/native/*nlm*
rm ${output_path}/${id}/*/native/*n3*
rm ${output_path}/${id}/*/cls/*Prob_Label*
