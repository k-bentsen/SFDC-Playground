public with sharing class OfflineProcessingSObjectInvocable
{
    public class Input
    {
        @InvocableVariable(label = 'SObjects')
        public List<SObject> sObjs;
        @InvocableVariable(label = 'DML Operation')
        public String operationType;
        @InvocableVariable(label = 'Configured Worker')
        public OLP_Worker__c worker;
    }

    public class Output
    {
        @InvocableVariable(label = 'Updated Worker')
        public OLP_Worker__c worker;

        public Output(OLP_Worker__c worker){
            this.worker = worker;
        }
    }

    @InvocableMethod(label = 'Process SObjects' category = 'Offline Processing')
    public static List<Output> submit(List<Input> inputs)
    {
        List<OLP_Worker__c> workersToQueue = new List<OLP_Worker__c>();
        List<Output> outputs = new List<Output>();
        for(Input inp: inputs)
        {
            OLP_Worker__c worker = new OLP_Worker__c();
            if(inp.worker != null) {
                worker = inp.worker;
            } else {
                worker.Type__c = 'SObject';
                worker.DML_Operation__c = inp.operationType;
            }
            worker.JSON_Parameters__c = JSON.serialize(inp.sObjs);
            worker.Status__c = 'Pending';
            workersToQueue.add(worker);
            Output output = new Output(worker);
            outputs.add(output);
        }
        insert as system workersToQueue;
        return outputs;
    }
}