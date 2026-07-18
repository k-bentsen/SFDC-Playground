/**
 * Author: Kyle Bentsen
 * GitHub: https://github.com/k-bentsen/Row2Flow
 * License: BSD 3-Clause License
 */

public virtual with sharing class Row2FlowSOQLBatchable extends Row2FlowBase implements Database.Batchable<SObject>, 
                                                                                Database.AllowsCallouts,
                                                                                Database.Stateful,
                                                                                Database.RaisesPlatformEvents
{
    private String soqlFilterConditions;

    public Row2FlowSOQLBatchable(Row_2_Flow_Configuration__mdt config)
    {
        super(config);
        this.soqlFilterConditions = config.SOQL_Query_Filter_Conditions__c;
    }

    public Row2FlowSOQLBatchable(String soqlFilterConditions, String flowName, Map<String, String> fieldToFlowInput)
    {
        super(flowName, fieldToFlowInput);
        this.soqlFilterConditions = soqlFilterConditions;
        resultsHandler.getRecord().Type__c = 'SOQL';
    }

    public Database.QueryLocator start(Database.BatchableContext bc)
    {
        setStartTime();
        resultsHandler.getRecord().Batch_Job_Id__c = bc.getJobId();
        return generateQuery();
    }

    public void execute(Database.BatchableContext bc, List<SObject> sObjs)
    {
        resultsHandler.initializeRowKeys();
        for(SObject so: sObjs) {
            resultsHandler.addRowKey(so.Id);
        }
        runFlowPerRow(sObjs);
    }

    public void finish(Database.BatchableContext bc)
    {
        if(generateResultsRec) {
            resultsHandler.saveResultRecord();
        }
    }

    protected virtual Database.QueryLocator generateQuery()
    {
        Set<String> queryFields = new Set<String>{'Id'};
        for(String keySource: fieldToFlowInput.keySet()){
            queryFields.add(keySource);
        }
        String query = 'SELECT ';
        for(String field: queryFields){
            query += field + ', ';
        }
        query = query.removeEnd(', ') + ' FROM ' + soqlFilterConditions;
        return Database.getQueryLocator(query);
    }

    private void runFlowPerRow(List<SObject> sObjs)
    {
        for(SObject so: sObjs)
        {
            Map<String, Object> flowParams = new Map<String, Object>(staticFlowParamValues);
            for(String sourceField: fieldToFlowInput.keySet())
            {
                Object val = so.get(sourceField);
                flowParams.put(fieldToFlowInput.get(sourceField), val);
            }
            processFlow(flowParams);
        }
    }
}