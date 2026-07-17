@isTest
private class OfflineProcessingTest
{
    private static OLP_Worker__c olpWorker = new OLP_Worker__c(Status__c = 'Pending');
    private static OLP_Run__c olpRun = new OLP_Run__c(Status__c = 'Initialized', Interval__c = '15 Minutes', Finish_Only__c = true);
    private static OfflineProcessing olp = new OfflineProcessing(olpWorker);

    @isTest
    private static void olpAsFlow()
    {
        setWorkerToFlow();
        insert olpWorker;

        Test.startTest();
            olp.doWork();
        Test.stopTest();

        Assert.areEqual('Completed', olpWorker.Status__c, 'Test worker record status should be set to Completed.');
    }

    @isTest
    private static void flowDeserializeParamsErr()
    {
        setWorkerToFlow();
        olpWorker.JSON_Parameters__c = '{val:"Test Value"}';
        insert olpWorker;

        Test.startTest();
            olp.doWork();
        Test.stopTest();

        Assert.areEqual('Error', olpWorker.Status__c, 'Test worker record status should be set to Error.');
        Assert.areEqual('Deserialization error', olpWorker.Error_Reason__c, 'Test worker record error reason should be Deserialization error.');
    }

    @isTest
    private static void invalidFlowErr()
    {
        setWorkerToFlow();
        olpWorker.Flow__c = 'Invalid__Flow_API__c';
        insert olpWorker;

        Test.startTest();
            olp.doWork();
        Test.stopTest();

        Assert.areEqual('Error', olpWorker.Status__c, 'Test worker record status should be set to Error.');
        Assert.areEqual('Invalid flow name', olpWorker.Error_Reason__c, 'Test worker record error reason should be Invalid flow name.');
    }

    @isTest
    private static void flowRuntimeErr()
    {
        setWorkerToFlow();
        olpWorker.JSON_Parameters__c = '{"Pass":"true", "Answer":"This does nothing", "Counter":false}';
        insert olpWorker;

        Test.startTest();
            olp.doWork();
        Test.stopTest();

        Assert.areEqual('Error', olpWorker.Status__c, 'Test worker record status should be set to Error.');
        Assert.isTrue(olpWorker.Error_Reason__c.contains('Flow encountered an error when processing and converting between data types.'), 'Test worker record error reason should mention flow processing and converting data types');
    }

    @isTest
    private static void olpAsSObjInsert()
    {
        setWorkerToDML();
        insert olpWorker;

        Test.startTest();
            olp.doWork();
        Test.stopTest();

        Assert.areEqual('Completed', olpWorker.Status__c, 'Test worker record status should be set to Completed.');
        List<OLP_Run__c> createdRecord = [SELECT Id, Status__c FROM OLP_Run__c];
        Assert.areEqual('Initialized', createdRecord[0].Status__c, 'There should be an OLP Run record created with a status of Initiated');
    }

    @isTest
    private static void olpAsSObjUpdate()
    {
        insert olpRun;
        setWorkerToDML();
        insert olpWorker;
        olpWorker.DML_Operation__c = 'UPDT';
        olpWorker.JSON_Parameters__c = '[{"attributes":{"type":"OLP_Run__c", "url": "/services/data/v55.0/sobjects/OLP_Run__c/' + olpRun.Id + '"}, "Id": "' + olpRun.Id + '","Status__c":"In Progress"}]';

        Test.startTest();
            olp.doWork();
        Test.stopTest();

        Assert.areEqual('Completed', olpWorker.Status__c, 'Test worker record status should be set to Completed.');
        List<OLP_Run__c> createdRecord = [SELECT Id, Status__c FROM OLP_Run__c];
        Assert.areEqual('In Progress', createdRecord[0].Status__c, 'The OLP Run record should be updated with a status of In Progress');
    }

    @isTest
    private static void olpAsSObjUpsert()
    {
        setWorkerToDML();
        insert olpWorker;
        olpWorker.DML_Operation__c = 'UPST';

        Test.startTest();
            olp.doWork();
        Test.stopTest();

        List<OLP_Run__c> createdRecord = [SELECT Id, Status__c FROM OLP_Run__c];
        Assert.areEqual('Initialized', createdRecord[0].Status__c, 'There should be an OLP Run record created with a status of Initiated');
    }

    @isTest
    private static void olpAsSObjDelete()
    {
        setWorkerToDML();
        insert olpWorker;
        OLP_Run__c olpRun = new OLP_Run__c();
        insert olpRun;
        olpWorker.DML_Operation__c = 'DLT';
        olpWorker.JSON_Parameters__c = '[{"attributes":{"type":"OLP_Run__c", "url": "/services/data/v55.0/sobjects/OLP_Run__c/' + olpRun.Id + '"}, "Id": "' + olpRun.Id + '"}]';

        Test.startTest();
            olp.doWork();
        Test.stopTest();

        List<OLP_Run__c> createdRecord = [SELECT Id, Status__c FROM OLP_Run__c];
        Assert.isTrue(createdRecord.isEmpty(), 'OLP Run record should be deleted.');
    }

    @isTest
    private static void olpAsSObjUndelete()
    {
        setWorkerToDML();
        insert olpWorker;
        OLP_Run__c olpRun = new OLP_Run__c();
        insert olpRun;
        delete olpRun;
        olpWorker.DML_Operation__c = 'UNDLT';
        olpWorker.JSON_Parameters__c = '[{"attributes":{"type":"OLP_Run__c", "url": "/services/data/v55.0/sobjects/OLP_Run__c/' + olpRun.Id + '"}, "Id": "' + olpRun.Id + '"}]';

        Test.startTest();
            olp.doWork();
        Test.stopTest();

        List<OLP_Run__c> createdRecord = [SELECT Id, Status__c FROM OLP_Run__c];
        Assert.areEqual(1, createdRecord.size(), 'OLP Run record should be undeleted.');
    }

    @isTest
    private static void sObjDeserializeErr()
    {
        setWorkerToDML();
        olpWorker.JSON_Parameters__c = '{val:"Test Value"}';
        insert olpWorker;

        Test.startTest();
            olp.doWork();
        Test.stopTest();

        Assert.areEqual('Error', olpWorker.Status__c, 'Test worker record status should be set to Error.');
        Assert.areEqual('Deserialization error', olpWorker.Error_Reason__c, 'Test worker record error reason should be Deserialization error.');
    }

    @isTest
    private static void sObjDMLErr()
    {
        setWorkerToDML();
        olpWorker.JSON_Parameters__c = '[{"attributes":{"type":"OLP_Worker__c"},"Type__c":"Invalid Type"}]';
        insert olpWorker;

        Test.startTest();
            olp.doWork();
        Test.stopTest();

        Assert.areEqual('Error', olpWorker.Status__c, 'Test worker record status should be set to Error.');
        Assert.isTrue(olpWorker.Error_Reason__c.contains('INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST'), 'Test worker record error reason should reference invalid picklist value.');
    }

    @isTest
    private static void olpAsExecutable()
    {
        setWorkerToExecutable();
        insert olpWorker;

        Test.startTest();
            olp.doWork();
        Test.stopTest();

        Assert.areEqual('Completed', olpWorker.Status__c, 'Test worker record status should be set to Completed.');
    }

    @isTest
    private static void executableInvalidClassErr()
    {
        setWorkerToExecutable();
        olpWorker.Class__c = 'Invalid__ClassName';
        insert olpWorker;

        Test.startTest();
            olp.doWork();
        Test.stopTest();

        Assert.areEqual('Error', olpWorker.Status__c, 'Test worker record status should be set to Error.');
        Assert.areEqual('Invalid or un-readable class', olpWorker.Error_Reason__c, 'Test worker record error reason should be Invalid or un-readable class.');
    }

    @isTest
    private static void executableDeserializeErr()
    {
        setWorkerToExecutable();
        olpWorker.JSON_Parameters__c = '{val:"Test Value"}';
        insert olpWorker;

        Test.startTest();
            olp.doWork();
        Test.stopTest();

        Assert.areEqual('Error', olpWorker.Status__c, 'Test worker record status should be set to Error.');
        Assert.areEqual('Deserialization error', olpWorker.Error_Reason__c, 'Test worker record error reason should be Deserialization error.');
    }

    @isTest
    private static void executableException()
    {
        setWorkerToExecutable();
        olpWorker.JSON_Parameters__c = '{"throwTestException":true}';
        insert olpWorker;

        Test.startTest();
            olp.doWork();
        Test.stopTest();

        Assert.areEqual('Error', olpWorker.Status__c, 'Test worker record status should be set to Error.');
        Assert.isTrue(olpWorker.Error_Reason__c.contains('Test Throw Exception'), 'Test worker record error reason should indicate a thrown exception.');
    }

    @isTest
    private static void olpRunAsBatch()
    {
        setWorkerToDML();
        insert olpWorker;

        Test.startTest();
            OfflineProcessing.process();
        Test.stopTest();

        List<OLP_Worker__c> updatedWorkers = [SELECT Status__c FROM OLP_Worker__c];
        Assert.areEqual('Completed', updatedWorkers[0].Status__c, 'The worker record should be marked as Completed by the executed batch job.');
    }

    @isTest
    private static void doNotProcessIfBatchAlreadyInProgress()
    {
        Id dummyCronId = '08e5900100MzxZ1AAJ'; //NOPMD
        setWorkerToDML();
        insert olpWorker;
        OfflineProcessing.process('15 Minutes', dummyCronId);
        Id resubmitJobId;

        Test.startTest();
            resubmitJobId = OfflineProcessing.process('15 Minutes', dummyCronId);
        Test.stopTest();

        Assert.isNull(resubmitJobId, 'If a job run is already in progress, a new async job should not be executed thus returning a null async job id.');
    }

    @isTest
    private static void manualReschedule()
    {
        System.schedule('OfflineProcessing @ - to abort', '0 00 * * * ?', new OfflineProcessingSchedulable());

        Test.startTest();
            OfflineProcessing.scheduleOLPIntervals();
        Test.stopTest();

        List<CronTrigger> scheduledOLPs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.JobType = '7' AND CronJobDetail.Name LIKE 'OfflineProcessing @%'];
        Assert.areEqual(4, scheduledOLPs.size(), 'There should be 4 scheduled OLP jobs for each 15 minutes.');
    }

    @isTest
    private static void sObjectInvocable()
    {
        OfflineProcessingSObjectInvocable.Input inp = new OfflineProcessingSObjectInvocable.Input();
        inp.sObjs = new List<OLP_Run__c>{olpRun};
        inp.operationType = 'INS';

        Test.startTest();
            OLP_Worker__c generetedWorker = OfflineProcessingSObjectInvocable.submit(new List<OfflineProcessingSObjectInvocable.Input>{inp})[0].worker;
            olp = new OfflineProcessing(generetedWorker);
            olp.doWork();
        Test.stopTest();

        List<OLP_Run__c> createdRecord = [SELECT Status__c FROM OLP_Run__c];
        Assert.areEqual(1, createdRecord.size(), 'The invocable should have inserted an OLP run record.');
        Assert.areEqual('Initialized', createdRecord[0].Status__c, 'The inserted OLP run record should be Initialized.');
    }

    @isTest
    private static void sObjectInvocablePreConfigured()
    {
        OfflineProcessingSObjectInvocable.Input inp = new OfflineProcessingSObjectInvocable.Input();
        inp.sObjs = new List<OLP_Run__c>{olpRun};
        olpWorker.Scheduled_Interval__c = '2 Hours';
        olpWorker.Self_Destruct__c = true;
        inp.worker = olpWorker;

        Test.startTest();
            OfflineProcessingSObjectInvocable.submit(new List<OfflineProcessingSObjectInvocable.Input>{inp});
        Test.stopTest();

        List<OLP_Worker__c> queuedWorker = [SELECT Scheduled_Interval__c, Self_Destruct__c FROM OLP_Worker__c];
        Assert.areEqual('2 Hours', queuedWorker[0].Scheduled_Interval__c, 'The pre-configured worker added to the queue should have its Interval value set to 2 Hours');
        Assert.areEqual(true, queuedWorker[0].Self_Destruct__c, 'The pre-configured worker added to the queue should have be set to self-destruct.');
    }

    @isTest
    private static void selfDestruct()
    {
        setWorkerToDML();
        olpWorker.Self_Destruct__c = true;
        insert olpWorker;

        Test.startTest();
            olp.doWork();
        Test.stopTest();

        List<OLP_Worker__c> updatedWorkers = [SELECT Id FROM OLP_Worker__c WHERE Id =: olpWorker.Id];
        Assert.areEqual(0, updatedWorkers.size(), 'The worker record should be deleted.');
    }

    private static void setWorkerToDML()
    {
        olpWorker.Type__c = 'SObject';
        olpWorker.DML_Operation__c = 'INS';
        olpWorker.JSON_Parameters__c = '[{"attributes":{"type":"OLP_Run__c"},"Status__c":"Initialized","Interval":"15 Minutes", "Finish_Only__c":true}]';
    }

    private static void setWorkerToExecutable()
    {
        olpWorker.Type__c = 'Apex Executable';
        olpWorker.Class__c = 'OfflineProcessingTest.SampleExecutable';
        olpWorker.JSON_Parameters__c = '{"val":"Test Value", "throwTestException":false}';
    }

    private static void setWorkerToFlow()
    {
        olpWorker.Type__c = 'Flow';
        olpWorker.Flow__c = 'OfflineProcessing_Test_Flow';
        olpWorker.JSON_Parameters__c = '{"Pass":true, "Answer":"This does nothing"}';
    }


    public class SampleExecutable implements OfflineProcessing.Executable
    {
        String val;
        Boolean throwTestException = false;

        public void execute()
        {
            if(this.throwTestException){
                throw new AsyncException('Test Throw Exception');
            }
        }
        
        public void finalize()
        {
            val = 'finished';
        }

        public void logException(Exception e)
        {

        }
    }
}