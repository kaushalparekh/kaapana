#bin/bash
shopt -s globstar
BATCH_COUNT=$(find "$BATCHES_INPUT_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)

echo "# "
echo "# BATCHES_INPUT_DIR:" $BATCHES_INPUT_DIR
echo "# BATCH_COUNT: " $BATCH_COUNT
echo "# "

echo "# "
echo "# Starting BATCH-ELEMENT-LEVEL ..."
echo "# "

loop_counter=0

for batch_dir in $BATCHES_INPUT_DIR/*
do
    batch_input_dir=${batch_dir}/${OPERATOR_IN_DIR}
    batch_original_img_dir=${batch_dir}/${ORG_IMG_IN_DIR}
    
    batch_output_dir=${batch_dir}/${OPERATOR_OUT_DIR}
    batch_name=$(basename -- "$batch_dir")
    
    echo "# "
    echo "# BATCH INPUT:        " $batch_input_dir
    echo "# BATCH ORIGINAL IMG: " $batch_original_img_dir
    echo "# BATCH OUTPUT DIR:   " $batch_output_dir
    echo "# "
    
    if [ ! -d "$batch_input_dir" ] || [ ! -d "$batch_original_img_dir" ]; then
        echo "# One of the input dirs does not exists. " 
        echo "# Skipping batch..."
        continue
    fi
    
    # check if no dcm extension is set
    if [[ $FORMAT = *[!\ ]* ]]; then
        extension_query="*.$FORMAT"
    else
        extension_query="*.nii.gz"
    fi

    input_file_count=$(find $batch_input_dir/ -type f -name "$extension_query" -printf x | wc -c)
    echo "# Found $input_file_count input files."

    original_file_count=$(find $batch_original_img_dir/ -type f -name "$extension_query" -printf x | wc -c)

    if [ "$original_file_count" -eq "1" ]; then

        shopt -s nullglob
        for input_file in $batch_input_dir/$extension_query; do
            echo "# "
            echo "# processing input-file: $input_file"
            echo "# "

            original_file=$(ls $batch_original_img_dir/$extension_query)
            output_filepath=${batch_output_dir}/$(basename -- "$input_file")
            install -Dv / $output_filepath

            echo "# "
            echo "# input_file:    " $input_file
            echo "# original_file: " $original_file
            echo "# output_file:   " $output_filepath
            echo "# "


            echo "# Starting conversion...."
            $EXECUTABLE -f "$original_file" -m "$input_file" -o "$output_filepath" --interpolator $INTERPOLATOR;
            if [ $? -ne 0 ]; then
                echo "# ERROR!"
                echo "# $EXECUTABLE FAILED"
                exit 1
            fi
            echo "# DONE"
            [ ! -f "$output_filepath" ] && { echo "# Error: Converted file not found!."; exit 2; }
            
            ((++loop_counter))
        done
    else
        echo "# Wrong file-count for $batch_original_img_dir/$extension_query!"
        echo "# Expected 1 - got: $original_file_count";
        exit 1;
    fi


done


echo "# "
echo "# Starting BATCH-LEVEL ..."
echo "# "

batch_input_dir=${WORKFLOW_DIR}/${OPERATOR_IN_DIR}
batch_original_img_dir=${WORKFLOW_DIR}/${ORG_IMG_IN_DIR}

batch_output_dir=${WORKFLOW_DIR}/${OPERATOR_OUT_DIR}
batch_name=$(basename -- "$WORKFLOW_DIR")

echo "# "
echo "# BATCH INPUT:        " $batch_input_dir
echo "# BATCH ORIGINAL IMG: " $batch_original_img_dir
echo "# BATCH OUTPUT DIR:   " $batch_output_dir
echo "# "

if [ -d "$batch_input_dir" ] || [ -d "$batch_original_img_dir" ]; then

    # check if no dcm extension is set
    if [[ $FORMAT = *[!\ ]* ]]; then
        extension_query="*.$FORMAT"
    else
        extension_query="*.nii.gz"
    fi

    input_file_count=$(find $batch_input_dir/ -type f -name "$extension_query" -printf x | wc -c)
    original_file_count=$(find $batch_original_img_dir/ -type f -name "$extension_query" -printf x | wc -c)
    echo "# Found $input_file_count input files."

    if [ "$original_file_count" -eq "1" ]; then

        shopt -s nullglob
        for input_file in $batch_input_dir/$extension_query; do
            echo "# "
            echo "# processing input-file: $input_file"
            echo "# "

            original_file=$(ls $batch_original_img_dir/$extension_query)
            output_filepath=${batch_output_dir}/$(basename -- "$input_file")
            install -Dv / $output_filepath

            echo "# "
            echo "# input_file:    " $input_file
            echo "# original_file: " $original_file
            echo "# output_file:   " $output_filepath
            echo "# "


            echo "# Starting conversion...."
            $EXECUTABLE -f "$original_file" -m "$input_file" -o "$output_filepath" --interpolator $INTERPOLATOR;
            if [ $? -ne 0 ]; then
                echo "# ERROR!"
                echo "# $EXECUTABLE FAILED"
                exit 1
            fi
            echo "# DONE"
            [ ! -f "$output_filepath" ] && { echo "# Error: Converted file not found!."; exit 2; }

            ((++loop_counter))
        done
    else
        echo "# ";
        echo "No valid files found on BATCH-LEVEL."
        echo "original_file_count: $original_file_count";
        echo "# ";
    fi
else
        echo "# Nothing found on BATCH-LEVEL..."
fi

if [[ "$loop_counter" -gt 0 ]] ; then
    echo "# Processed $loop_counter files - ok";
    echo "# File-Resample done!";
    exit 0;
else
    echo "# Nothing was processed!";
    echo "# EXIT!";
    exit 1;
fi;

echo "# DONE";
