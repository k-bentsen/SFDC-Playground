public without sharing class OfflineProcessing
{
    private OLP_Worker__c worker;
    private Boolean hasError = false;

    public OfflineProcessing(OLP_Worker__c worker)
    {
        this.worker = worker;
    }

    public void doWork()
    {
        worker.Status__c = 'Processing';
        update as system worker;
        switch on worker.Type__c{
            when 'Flow'{
                processFlow();
            }
            when 'SObject'{
                processDML();
            }
            when 'Apex Executable'{
                processExecutable();
            }
        }
        if(!hasError)
        {
            worker.Error_Reason__c = '';
            worker.Error_Stack_Trace__c = '';
            worker.Status__c = 'Completed';
        }
        if(worker.Status__c == 'Completed' && worker.Self_Destruct__c) {
            delete as system worker;
        } else {
            update as system worker;
        }
    }

    private void processFlow()
    {
        Map<String, Object> flowParams;
        try {
            flowParams = (Map<String, Object>)JSON.deserializeUntyped(worker.JSON_Parameters__c);
        } catch(JSONException jsonExc) {
            setDeserializeError(jsonExc);
        }
        if(!hasError)
        {
            try {
                Flow.Interview flowRun = Flow.Interview.createInterview(worker.Flow__c, flowParams);
                flowRun.start();
            } catch(TypeException te) {
                setError('Invalid flow name', te);
            } catch (Exception e) {
                setError(e.getMessage(), e);
            }
        }
    }

    private void processDML()
    {
        List<SObject> sObjs;
        try{
            sObjs = (List<SObject>)JSON.deserialize(worker.JSON_Parameters__c, List<SObject>.class);
        } catch (JSONException jsonExc){
            setDeserializeError(jsonExc);
        }
        if(!hasError) {
            doDML(sObjs, worker.DML_Operation__c);
        }
    }

    private void doDML(List<SObject> sObjs, String operation)
    {
        try{
            switch on operation
            {
                when 'INS' {
                    insert as system sObjs;
                }
                when 'UPDT' {
                    update as system sObjs;
                }
                when 'UPST' {
                    upsert as system sObjs;
                }
                when 'DLT' {
                    delete as system sObjs;
                }
                when 'UNDLT' {
                    undelete as system sObjs;
                }
            }
        } catch(Exception e){
            setError(e.getMessage(), e);
        }
    }

    private void processExecutable()
    {
        Type classType = Type.forName(worker.Class__c);
        if(classType == null)
        {
            setError('Invalid or un-readable class', new TypeException('Invalid or un-readable class'));
            return;
        }
        Executable executor;
        try{
            executor = (Executable)JSON.deserialize(worker.JSON_Parameters__c, classType);
            executor.execute();
            executor.finalize();
        } catch (JSONException jsonExc) {
            setDeserializeError(jsonExc);
        } catch (Exception e) {
            setError(e.getMessage(), e);
            executor.logException(e);
        }
    }

    private void setError(String errMsg, Exception e)
    {
        hasError = true;
        worker.Status__c = 'Error';
        worker.Error_Reason__c = errMsg.left(255);
        worker.Error_Stack_Trace__c = e.getTypeName() + ' : ' + e.getMessage() + '\n' + e.getStackTraceString();
    }

    private void setDeserializeError(Exception e)
    {
        setError('Deserialization error', e);
    }

    public static Id process()
    {
        return process('15 Minutes', null);
    }

    public static Id process(String interval, Id cronTriggerId)
    {
        Id asyncJobId;
        List<OLP_Run__c> currentOLPRuns = [SELECT Status__c FROM OLP_Run__c WHERE (NOT Status__c LIKE 'Finished%') AND Cron_Trigger_Id__c = :cronTriggerId AND (NOT Cron_Trigger_Id__c = NULL) WITH SYSTEM_MODE];
        if(!currentOLPRuns.isEmpty()) {
            return null;
        }

        DateTime currTime = System.now();
        String olpWorkerQueryStr = 'SELECT Type__c, Status__c, Hold_Until__c, JSON_Parameters__c, Class__c, Flow__c, DML_Operation__c, Scheduled_Interval__c, Self_Destruct__c FROM OLP_Worker__c ' + WHERE_CLAUSE;
        Integer pendingOLPCount = Database.countQuery('SELECT COUNT() FROM OLP_Worker__c ' + WHERE_CLAUSE);
        OLP_Run__c olpRun = new OLP_Run__c(Cron_Trigger_Id__c = cronTriggerId, Status__c = 'Initialized', Count_of_Workers__c = pendingOLPCount, Interval__c = interval);
        insert as system olpRun;
        OfflineProcessingBatchable olpBatchRun = new OfflineProcessingBatchable(olpWorkerQueryStr, interval, olpRun);
        
        Integer batchSize = intervalsToBatchSize.containsKey(interval) ? intervalsToBatchSize.get(interval) : 1;
        
        if(pendingOLPCount == 0)
        {
            olpRun.Finish_Only__c = true;
            olpRun.Start_Time__c = System.NOW();
            update as system olpRun;
            olpBatchRun.finish(null);
        } else {
            asyncJobId = Database.executeBatch(olpBatchRun, batchSize);
        }
        return asyncJobId;
    }

    public static void scheduleOLPIntervals()
    {
        abortActiveJobs();
        System.schedule('OfflineProcessing @ 00', '0 00 * * * ?', new OfflineProcessingSchedulable());
        System.schedule('OfflineProcessing @ 15', '0 15 * * * ?', new OfflineProcessingSchedulable());
        System.schedule('OfflineProcessing @ 30', '0 30 * * * ?', new OfflineProcessingSchedulable());
        System.schedule('OfflineProcessing @ 45', '0 45 * * * ?', new OfflineProcessingSchedulable());
        System.schedule('OfflineProcessing every 2 Hours', '0 0 0/2 * * ?', new OfflineProcessingSchedulable().withInterval('2 Hours'));
        System.schedule('OfflineProcessing every 6 Hours', '0 0 0/6 * * ?', new OfflineProcessingSchedulable().withInterval('6 Hours'));
        System.schedule('OfflineProcessing every 24 Hours', '0 0 3 ? * * *', new OfflineProcessingSchedulable().withInterval('24 Hours'));
    }

    public static void abortActiveJobs()
    {
        List<CronTrigger> existingOLPScheduledJobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.JobType = '7' AND CronJobDetail.Name LIKE 'OfflineProcessing%' WITH SYSTEM_MODE];
        for(CronTrigger ct: existingOLPScheduledJobs) {
            System.abortJob(ct.Id);
        }
    }

    public static final String WHERE_CLAUSE = 'WHERE Status__c = \'Pending\' AND (Scheduled_Interval__c = null OR Scheduled_Interval__c = :interval) AND (Hold_Until__c = NULL or Hold_Until__c <= :currTime) WITH SYSTEM_MODE';

    private static final Map<String, Integer> intervalsToBatchSize = new Map<String, Integer>{ //NOPMD
        '15 Minutes' => 1,
        '2 Hours' => 1,
        '6 Hours' => 1,
        '24 Hours' => Integer.valueOf(System.Label.OLP_24_Hour_Batch_Size)
    };

    public Interface Executable
    {
        void execute();
        void finalize();
        void logException(Exception e);
    }
}