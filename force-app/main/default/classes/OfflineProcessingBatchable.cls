public with sharing class OfflineProcessingBatchable implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful
{
    private List<OLP_Worker__c> olpWorkers;
    private OLP_Run__c olpRun;
    private String queryStr;
    private String interval;
    private DateTime currTime;
    private Integer workersProcessed = 0;

    public OfflineProcessingBatchable(String queryStr, String interval, OLP_Run__c olpRun)
    {
        this.queryStr = queryStr;
        this.interval = interval;
        this.olpRun = olpRun;
        currTime = System.NOW();
    }

    public Database.QueryLocator start(Database.BatchableContext bc)
    {
        olpRun.Start_Time__c = System.NOW();
        olpRun.Batch_Job_Id__c = bc.getJobId();
        olpRun.Status__c = 'In Progress';
        update olpRun;
        return Database.getQueryLocator(queryStr);
    }

    public void execute(Database.BatchableContext bc, List<OLP_Worker__c> olpWorkers)
    {
        for(OLP_Worker__c worker: olpWorkers)
        {
            worker.OLP_Run__c = olpRun.Id;
            OfflineProcessing olpWork = new OfflineProcessing(worker);
            olpWork.doWork();
            workersProcessed++;
        }
        olpRun.Workers_Processed__c = workersProcessed;
        update olpRun;
        update olpWorkers;
    }

    public void finish(Database.BatchableContext bc)
    {
        olpRun.End_Time__c = System.NOW();
        olpRun.Status__c = 'Finished';
        if(olpRun.Count_of_Workers__c > 0) { 
            update olpRun;
        } else {
            delete olpRun;
        }
    }
}