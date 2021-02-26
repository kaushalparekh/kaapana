import os
import glob
import functools
from datetime import timedelta

from airflow.operators.python_operator import PythonOperator
from airflow.utils.decorators import apply_defaults
from kaapana.operators.KaapanaBaseOperator import KaapanaBaseOperator, default_registry, default_project

def rest_self_udpate(func):
    @functools.wraps(func)
    def wrapper(self, *args, **kwargs):
        if kwargs["dag_run"]  is not None and 'rest_call' in kwargs["dag_run"].conf and kwargs["dag_run"].conf['rest_call'] is not None:
            payload = kwargs["dag_run"].conf['rest_call']
            if self.name in payload:
                operator_conf = payload[self.name]       
                for k, v in operator_conf.items():
                    if k in self.__dict__.keys():
                        print(f'Adjusting {k} from {self.__dict__[k]} to {v}')
                        self.__dict__[k] =v
        return func(self, *args, **kwargs)
    return wrapper

class KaapanaPythonBaseOperator(PythonOperator):
    def __init__(
        self,
        dag,
        name,
        python_callable,
        operator_out_dir=None,
        input_operator=None,
        operator_in_dir=None,
        task_id=None,
        parallel_id=None,
        keep_parallel_id=True,
        trigger_rule='all_success',
        retries=1,
        retry_delay=timedelta(seconds=30),
        execution_timeout=timedelta(minutes=30),
        task_concurrency=None,
        pool=None,
        pool_slots=None,
        ram_mem_mb=100,
        ram_mem_mb_lmt=None,
        cpu_millicores=None,
        cpu_millicores_lmt=None,
        gpu_mem_mb=None,
        gpu_mem_mb_lmt=None,
        manage_cache=None,
        *args, **kwargs
    ):

        KaapanaBaseOperator.set_defaults(
            self,
            name=name,
            task_id=task_id,
            operator_out_dir=operator_out_dir,
            input_operator=input_operator,
            operator_in_dir=operator_in_dir,
            parallel_id=parallel_id,
            keep_parallel_id=keep_parallel_id,
            trigger_rule=trigger_rule,
            pool=pool,
            pool_slots=pool_slots,
            ram_mem_mb=ram_mem_mb,
            ram_mem_mb_lmt=ram_mem_mb_lmt,
            cpu_millicores=cpu_millicores,
            cpu_millicores_lmt=cpu_millicores_lmt,
            gpu_mem_mb=gpu_mem_mb,
            gpu_mem_mb_lmt=gpu_mem_mb_lmt,
            manage_cache=manage_cache
        )

        super().__init__(
            dag=dag,
            python_callable=python_callable,
            task_id=self.task_id,
            trigger_rule=self.trigger_rule,
            provide_context=True,
            retry_delay=retry_delay,
            retries=retries,
            task_concurrency=task_concurrency,
            execution_timeout=execution_timeout,
            executor_config=self.executor_config,
            pool=self.pool,
            pool_slots=self.pool_slots,
            *args,
            **kwargs
        )

    def post_execute(self, context, result=None):
        pass
