#bin/bash

set -e

export OMP_THREAD_LIMIT=1
export OMP_NUM_THREADS=1

TASK_NUM=$(echo "$TASK" | tr -dc '0-9')

echo "#######################################################################"
echo "#"
echo "# Starting nnUNet..."
echo "#"
echo "# MODE:     $MODE";
echo "# TASK:     $TASK";
echo "# TASK_NUM: $TASK_NUM";
echo "#"
if [ "$MODE" != "training" ] && [ "$MODE" != "inference" ]  && [ "$MODE" != "preprocess" ] && [ "$MODE" != "export-model" ] && [ "$MODE" != "zip-model" ] && [ "$MODE" != "install-model" ] && [ "$MODE" != "identify-best" ]; then
    echo "#"
    echo "#######################################################################"
    echo "#"
    echo "# MODE ($MODE) NOT SUPPORTED";
    echo "# OPTIONS: preprocess, training, inference,identify-best,export-model,install-model";
    echo "#"
    echo "#######################################################################"
    echo "#"
    exit 1
fi

if [ "$MODE" = "preprocess" ]; then
    export nnUNet_raw_data_base="/$WORKFLOW_DIR/$OPERATOR_OUT_DIR"
    export nnUNet_preprocessed="$nnUNet_raw_data_base/nnUNet_preprocessed"
    export RESULTS_FOLDER="$nnUNet_raw_data_base/results"
    
    echo "#"
    echo "# Starting preprocessing..."
    echo "#"
    echo "# PREPROCESS:      $PREP_PREPROCESS";
    echo "# CHECK_INTEGRITY: $PREP_CHECK_INTEGRITY";
    echo "#"
    echo "# OMP_THREAD_LIMIT" $OMP_THREAD_LIMIT
    echo "# OMP_NUM_THREADS" $OMP_NUM_THREADS
    echo "# PREP_TL" $PREP_TL
    echo "# PREP_TF" $PREP_TF
    echo "#"
    echo "# NIFTI_DIRS: $INPUT_NIFTI_DIRS";
    echo "# LABEL_DIR: $PREP_LABEL_DIR";
    echo "# MODALITIES: $PREP_MODALITIES";
    echo "#"
    echo "# nnUNet_raw_data_base: $nnUNet_raw_data_base";
    echo "# nnUNet_preprocessed:  $nnUNet_preprocessed";
    echo "# RESULTS_FOLDER:       $RESULTS_FOLDER";
    echo "#"
    echo "# Starting create_dataset..."
    echo "#"
    python3 -u ./create_dataset.py
    
    if [ "$PREP_CHECK_INTEGRITY" = "True" ] || [ "$PREP_CHECK_INTEGRITY" = "true" ]; then
        preprocess_verify="--verify_dataset_integrity"
    else
        preprocess_verify=""
    fi
    
    if [ "$PREP_PREPROCESS" = "True" ] || [ "$PREP_PREPROCESS" = "true" ]; then
        preprocess=""
    else
        preprocess="-no_pp"
    fi
    
    echo "# COMMAND: nnUNet_plan_and_preprocess -t $TASK_NUM -tl $PREP_TL -tf $PREP_TF $preprocess $preprocess_verify"
    echo "#"
    nnUNet_plan_and_preprocess -t $TASK_NUM -tl $PREP_TL -tf $PREP_TF $preprocess $preprocess_verify
    echo "#"
    echo "# Dataset itegrity OK!"
    echo "#"
    
elif [ "$MODE" = "training" ]; then
    export nnUNet_raw_data_base="/$WORKFLOW_DIR/$OPERATOR_IN_DIR"
    export nnUNet_preprocessed="$nnUNet_raw_data_base/nnUNet_preprocessed"
    export RESULTS_FOLDER="/$WORKFLOW_DIR/$OPERATOR_OUT_DIR/results"
    # export RESULTS_FOLDER="$nnUNet_raw_data_base/results"
    
    TENSORBOARD_DIR="/$WORKFLOW_DIR/$OPERATOR_OUT_DIR/tensorboard"

    echo "#"
    echo "# Starting training..."
    echo "#"
    echo "# FOLD: $TRAIN_FOLD";
    echo "# TASK: $TASK";
    echo "# NETWORK: $TRAIN_NETWORK";
    echo "# NETWORK_TRAINER: $TRAIN_NETWORK_TRAINER";
    echo "#"
    echo "# nnUNet_raw_data_base: $nnUNet_raw_data_base"
    echo "# nnUNet_preprocessed:  $nnUNet_preprocessed"
    echo "# RESULTS_FOLDER:       $RESULTS_FOLDER"
    echo "# TENSORBOARD_DIR:      $TENSORBOARD_DIR"
    echo "#"
    echo "# TRAIN_CONTINUE:       $TRAIN_CONTINUE"
    echo "# TRAIN_NPZ:            $TRAIN_NPZ"
    echo "#"

    echo "# Writing model_info.json ...:";
    python3 -u /src/write_model_info.py $RESULTS_FOLDER
    
    if ! [ -z "${TENSORBOARD_DIR}" ]; then
        echo "# Starting monitoring:";
        python3 -u /src/monitoring.py $RESULTS_FOLDER $TRAIN_FOLD $TENSORBOARD_DIR &
        echo "#"
    fi
    
    if [ "$TRAIN_CONTINUE" = "True" ] || [ "$TRAIN_CONTINUE" = "true" ]; then
        continue="--continue_training"
    else
        continue=""
    fi
    
    if [ "$TRAIN_NPZ" = "True" ] || [ "$TRAIN_NPZ" = "true" ]; then
        npz="--npz"
    else
        npz=""
    fi
    
    echo "#"
    echo "# COMMAND: nnUNet_train $TRAIN_NETWORK $TRAIN_NETWORK_TRAINER $TASK $TRAIN_FOLD $npz $continue"
    nnUNet_train $TRAIN_NETWORK $TRAIN_NETWORK_TRAINER $TASK $TRAIN_FOLD $npz $continue
    
    CREATE_REPORT="True"

    if [ "$CREATE_REPORT" = "True" ] || [ "$CREATE_REPORT" = "true" ]; then
        echo "# Starting create_report ..."
        python3 -u /src/create_report.py $RESULTS_FOLDER "/data/$OPERATOR_OUT_DIR"
        echo "# Report created."
        echo "#"
    fi

    
    echo "#"
    echo "# DONE"
    
elif [ "$MODE" = "inference" ]; then
    export nnUNet_raw_data_base="/$WORKFLOW_DIR/$OPERATOR_OUT_DIR"
    export nnUNet_preprocessed="$nnUNet_raw_data_base/nnUNet_preprocessed"
    export RESULTS_FOLDER="/models"
    shopt -s globstar
    BATCH_COUNT=$(find "$BATCHES_INPUT_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
    
    echo "#"
    echo "# Starting inference..."
    echo "#"
    echo "# THREADS_PREP:  $INF_THREADS_PREP";
    echo "# THREADS_NIFTI: $INF_THREADS_NIFTI";
    echo "# PREPARATION:   $INF_PREPARATION";
    echo "#"
    echo "# INPUT_NIFTI_DIRS: $INPUT_NIFTI_DIRS";
    echo "#"
    echo "# WORKFLOW_DIR:     $WORKFLOW_DIR"
    echo "# OPERATOR_OUT_DIR: $OPERATOR_OUT_DIR"
    echo "#"
    echo "# nnUNet_raw_data_base: $nnUNet_raw_data_base"
    echo "# nnUNet_preprocessed: $nnUNet_preprocessed"
    echo "# RESULTS_FOLDER: $RESULTS_FOLDER"
    echo "#"
    echo "# BATCH_COUNT: " $BATCH_COUNT
    echo "#"
    
    if [ $BATCH_COUNT -eq 0 ]; then
        echo "# No batch-data found -> abort."
        exit 1
    else
        echo "# Found $BATCH_COUNT batches."
    fi
    echo "#";
    echo "# Starting batch loop...";
    echo "#";
    
    for batch_dir in $BATCHES_INPUT_DIR/*
    do
        
        batch_name=$(basename -- "$batch_dir")
        
        echo "# TASK" $TASK
        echo "# MODEL" $MODEL
        echo "# INPUT_DIRS" $INPUT_DIRS
        echo "# batch_dir" $batch_dir
        echo "# batch_name" $batch_name
        echo "# MODE" $MODE
        echo "#"
        echo "#"
        
        operator_input_dir=${batch_dir}/${OPERATOR_IN_DIR}
        
        operator_output_dir=${batch_dir}/${OPERATOR_OUT_DIR}
        mkdir -p $operator_output_dir
        
        if [ "$INF_PREPARATION" = "true" ] || [ "$INF_PREPARATION" = "True" ] ; then
            echo "############# Starting nnUNet file preparation..."
            python3 -u ./preparation.py
            if [ $? -eq 0 ]; then
                echo "# Data preparation successful!"
            else
                echo "# Data preparation failed!"
                exit 1
            fi
        else
            echo "############# nnUNet file preparation is turned off! (PREPARATION: '$INF_PREPARATION')"
            find . -name $operator_input_dir\*.nii* -exec cp {} $nnUNet_raw_data_base \;
            
        fi
        
        echo "############# Starting nnUNet prediction..."
        echo "COMMAND: nnUNet_predict -t $TASK -i $nnUNet_raw_data_base -o $operator_output_dir -m $MODEL --num_threads_preprocessing $INF_THREADS_PREP --num_threads_nifti_save $INF_THREADS_NIFTI --disable_tta --mode fast --all_in_gpu False"
        nnUNet_predict -t $TASK -i $nnUNet_raw_data_base -o $operator_output_dir -m $MODEL --num_threads_preprocessing $INF_THREADS_PREP --num_threads_nifti_save $INF_THREADS_NIFTI --disable_tta --mode fast --all_in_gpu False
        if [ $? -eq 0 ]; then
            echo "############# Prediction successful!"
        else
            echo "############# Prediction failed!"
            exit 1
        fi
    done
    
elif [ "$MODE" = "identify-best" ]; then
    export nnUNet_raw_data_base="/$WORKFLOW_DIR/$OPERATOR_IN_DIR"
    export nnUNet_preprocessed="$nnUNet_raw_data_base/nnUNet_preprocessed"
    export RESULTS_FOLDER="$nnUNet_raw_data_base/results"
    
    echo "#"
    echo "# Starting identify-best..."
    echo "#"
    echo "#"
    echo "# nnUNet_raw_data_base:  $nnUNet_raw_data_base"
    echo "# nnUNet_preprocessed:   $nnUNet_preprocessed"
    echo "# RESULTS_FOLDER:        $RESULTS_FOLDER"
    echo "#"
    echo "# FOLD:                 $TRAIN_FOLD"
    echo "# TASK:                  $TASK"
    echo "# TRAIN_NETWORK:         $TRAIN_NETWORK"
    echo "# TRAIN_NETWORK_TRAINER: $TRAIN_NETWORK_TRAINER"
    echo "# model_output_path:     $model_output_path"
    echo "#"
    echo "#"

    # models="2d 3d_fullres 3d_lowres 3d_cascade_fullres"

    if [ "$TRAIN_STRICT" = "True" ] || [ "$TRAIN_STRICT" = "true" ]; then
        strict="--strict"
    else
        strict=""
    fi

    echo "# COMMAND: nnUNet_find_best_configuration -m $TRAIN_NETWORK -t $TASK_NUM $strict"
    nnUNet_find_best_configuration -m $TRAIN_NETWORK -t $TASK_NUM $strict

    echo "#"
    echo "# DONE"

elif [ "$MODE" = "zip-model" ]; then
    export nnUNet_raw_data_base="/$WORKFLOW_DIR/$OPERATOR_IN_DIR"
    export nnUNet_preprocessed="$nnUNet_raw_data_base/nnUNet_preprocessed"
    export RESULTS_FOLDER="$nnUNet_raw_data_base/results"
    
    mkdir -p "/$WORKFLOW_DIR/$OPERATOR_OUT_DIR/"
    TIMESTAMP=`date +%Y-%m-%d_%H-%M`
    model_output_path="/$WORKFLOW_DIR/$OPERATOR_OUT_DIR/nnunet_$TASK_$TRAIN_NETWORK_$TIMESTAMP.zip"
    
    echo "#"
    echo "# Starting export-model..."
    echo "#"
    echo "#"
    echo "# nnUNet_raw_data_base:  $nnUNet_raw_data_base"
    echo "# nnUNet_preprocessed:   $nnUNet_preprocessed"
    echo "# RESULTS_FOLDER:        $RESULTS_FOLDER"
    echo "#"
    echo "# FOLD:                  $TRAIN_FOLD"
    echo "# TASK:                  $TASK"
    echo "# TRAIN_NETWORK:         $TRAIN_NETWORK"
    echo "# TRAIN_NETWORK_TRAINER: $TRAIN_NETWORK_TRAINER"
    echo "# model_output_path:     $model_output_path"
    echo "#"
    echo "# COMMAND: zip -r $model_output_path $RESULTS_FOLDER/nnUNet/"
    echo "#"
    zip -r "$model_output_path" "$RESULTS_FOLDER/nnUNet/"
    
    echo "# DONE"

elif [ "$MODE" = "export-model" ]; then
    export nnUNet_raw_data_base="/$WORKFLOW_DIR/$OPERATOR_IN_DIR"
    export nnUNet_preprocessed="$nnUNet_raw_data_base/nnUNet_preprocessed"
    export RESULTS_FOLDER="$nnUNet_raw_data_base/results"
    
    mkdir -p "/$WORKFLOW_DIR/$OPERATOR_OUT_DIR/"
    model_output_path="/$WORKFLOW_DIR/$OPERATOR_OUT_DIR/nnunet_model_$TRAIN_NETWORK.zip"
    
    echo "#"
    echo "# Starting export-model..."
    echo "#"
    echo "#"
    echo "# nnUNet_raw_data_base:  $nnUNet_raw_data_base"
    echo "# nnUNet_preprocessed:   $nnUNet_preprocessed"
    echo "# RESULTS_FOLDER:        $RESULTS_FOLDER"
    echo "#"
    echo "# FOLD:                 $TRAIN_FOLD"
    echo "# TASK:                  $TASK"
    echo "# TRAIN_NETWORK:         $TRAIN_NETWORK"
    echo "# TRAIN_NETWORK_TRAINER: $TRAIN_NETWORK_TRAINER"
    echo "# model_output_path:     $model_output_path"
    echo "#"
    echo "#"
    echo "# COMMAND: nnUNet_export_model_to_zip -t $TASK -m $TRAIN_NETWORK -tr $TRAIN_NETWORK_TRAINER -o $model_output_path "
    echo "#"
    echo "# DONE"
    nnUNet_export_model_to_zip -t $TASK -m $TRAIN_NETWORK -tr $TRAIN_NETWORK_TRAINER -o $model_output_path -f 0 1 2 3 4
    
elif [ "$MODE" = "install-model" ]; then
    export nnUNet_raw_data_base="/$WORKFLOW_DIR/$OPERATOR_IN_DIR"
    export nnUNet_preprocessed="$nnUNet_raw_data_base/nnUNet_preprocessed"
    export RESULTS_FOLDER="/models"
    
    mkdir -p "/$WORKFLOW_DIR/$OPERATOR_OUT_DIR/"
    model_output_path="/$WORKFLOW_DIR/$OPERATOR_OUT_DIR/nnunet_model_$TRAIN_NETWORK.zip"
    
    echo "#"
    echo "# Starting install-model..."
    echo "#"
    echo "#"
    echo "# nnUNet_raw_data_base:  $nnUNet_raw_data_base"
    echo "# nnUNet_preprocessed:   $nnUNet_preprocessed"
    echo "# RESULTS_FOLDER:        $RESULTS_FOLDER"
    echo "#"
    echo "# FOLD:                 $TRAIN_FOLD"
    echo "# TASK:                  $TASK"
    echo "# TRAIN_NETWORK:         $TRAIN_NETWORK"
    echo "# TRAIN_NETWORK_TRAINER: $TRAIN_NETWORK_TRAINER"
    echo "# model_output_path:     $model_output_path"
    echo "#"
    echo "#"
    
    cd "/$WORKFLOW_DIR/$OPERATOR_IN_DIR"

    shopt -s nullglob
    for MODEL_PATH in *.zip; do
        echo "Found zip-file: $MODEL_PATH"
        echo "Installing: nnUNet_install_pretrained_model_from_zip $MODEL_PATH"
        nnUNet_install_pretrained_model_from_zip $MODEL_PATH
        
    done
    echo "#"
    echo "# DONE"
    
fi;

echo "#"
echo "#"
echo "##########################        DONE       ##########################"
echo "#"
echo "#######################################################################"
exit 0

# usage: nnUNet_plan_and_preprocess [-h] [-t TASK_NAMES [TASK_NAMES ...]]
#                                   [-pl3d PLANNER3D] [-pl2d PLANNER2D] [-no_pp]
#                                   [-tl TL] [-tf TF]
#                                   [--verify_dataset_integrity]

# optional arguments:
#   -h, --help            show this help message and exit
#   -t TASK_NAMES [TASK_NAMES ...], --TASK_NAMEs TASK_NAMES [TASK_NAMES ...]
#                         List of integers belonging to the task ids you wish to
#                         run experiment planning and preprocessing for. Each of
#                         these ids must, have a matching folder 'TaskXXX_' in
#                         the raw data folder
#   -pl3d PLANNER3D, --planner3d PLANNER3D
#                         Name of the ExperimentPlanner class for the full
#                         resolution 3D U-Net and U-Net cascade. Default is
#                         ExperimentPlanner3D_v21. Can be 'None', in which case
#                         these U-Nets will not be configured
#   -pl2d PLANNER2D, --planner2d PLANNER2D
#                         Name of the ExperimentPlanner class for the 2D U-Net.
#                         Default is ExperimentPlanner2D_v21. Can be 'None', in
#                         which case this U-Net will not be configured
#   -no_pp                Set this flag if you dont want to run the
#                         preprocessing. If this is set then this script will
#                         only run the experiment planning and create the plans
#                         file
#   -tl TL                Number of processes used for preprocessing the low
#                         resolution data for the 3D low resolution U-Net. This
#                         can be larger than -tf. Don't overdo it or you will
#                         run out of RAM
#   -tf TF                Number of processes used for preprocessing the full
#                         resolution data of the 2D U-Net and 3D U-Net. Don't
#                         overdo it or you will run out of RAM
#   --verify_dataset_integrity
#                         set this flag to check the dataset integrity. This is
#                         useful and should be done once for each dataset!

# usage: nnUNet_train [-h] [-val] [-c] [-p P] [--use_compressed_data]
#                     [--deterministic] [--npz] [--find_lr] [--valbest] [--fp32]
#                     [--val_folder VAL_FOLDER]
#                     network network_trainer task fold

# positional arguments:
#   network
#   network_trainer
#   task                  can be task name or task id
#   fold                  0, 1, ..., 5 or 'all'

# optional arguments:
#   -h, --help            show this help message and exit
#   -val, --validation_only
#                         use this if you want to only run the validation
#   -c, --continue_training
#                         use this if you want to continue a training
#   -p P                  plans identifier. Only change this if you created a
#                         custom experiment planner
#   --use_compressed_data
#                         If you set use_compressed_data, the training cases
#                         will not be decompressed. Reading compressed data is
#                         much more CPU and RAM intensive and should only be
#                         used if you know what you are doing
#   --deterministic       Makes training deterministic, but reduces training
#                         speed substantially. I (Fabian) think this is not
#                         necessary. Deterministic training will make you
#                         overfit to some random seed. Don't use that.
#   --npz                 if set then nnUNet will export npz files of predicted
#                         segmentations in the validation as well. This is
#                         needed to run the ensembling step so unless you are
#                         developing nnUNet you should enable this
#   --find_lr             not used here, just for fun
#   --valbest             hands off. This is not intended to be used
#   --fp32                disable mixed precision training and run old school
#                         fp32
#   --val_folder VAL_FOLDER
#                         name of the validation folder. No need to use this for
#                         most people
