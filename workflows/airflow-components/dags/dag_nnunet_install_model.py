from airflow.utils.log.logging_mixin import LoggingMixin
from airflow.utils.dates import days_ago
from datetime import timedelta
from airflow.models import DAG

from kaapana.operators.LocalGetInputDataOperator import LocalGetInputDataOperator
from kaapana.operators.LocalGetRefSeriesOperator import LocalGetRefSeriesOperator
from kaapana.operators.LocalWorkflowCleanerOperator import LocalWorkflowCleanerOperator
from kaapana.operators.Bin2DcmOperator import Bin2DcmOperator


ui_forms = {
    "workflow_form": {
        "type": "object",
        "properties": {
            "combination_method": {
                "title": "method",
                "description": "Select the method for model merging.",
                "enum": ["averaging","test2","test3"],
                "default": 'averaging',
                "required": True
            },
            "input": {
                "title": "Input Modality",
                "default": "OT",
                "description": "Expected input modality.",
                "type": "string",
                "readOnly": True,
            },
        }
    }
}
args = {
    'ui_visible': True,
    'ui_forms': ui_forms,
    'owner': 'kaapana',
    'start_date': days_ago(0),
    'retries': 0,
    'retry_delay': timedelta(seconds=60)
}

dag = DAG(
    dag_id='nnunet-install-model',
    default_args=args,
    concurrency=1,
    max_active_runs=1,
    schedule_interval=None
)

get_input = LocalGetInputDataOperator(
    dag=dag,
    check_modality=True,
    parallel_downloads=5
)

get_ref_ct_series_from_seg = LocalGetRefSeriesOperator(
    dag=dag,
    input_operator=get_input,
    search_policy="study_uid",
    expected_file_count="all",
    modality="OT",
    parallel_downloads=5,
)

dcm2bin = Bin2DcmOperator(
    dag=dag,
    input_operator=get_ref_ct_series_from_seg,
    name="extract-binary",
    file_extensions="*.dcm"
)

#clean = LocalWorkflowCleanerOperator(dag=dag,clean_workflow_dir=True)

get_input >> get_ref_ct_series_from_seg >> dcm2bin #>> clean
