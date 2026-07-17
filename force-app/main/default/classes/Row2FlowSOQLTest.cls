/**
 * Author: Kyle Bentsen
 * GitHub: https://github.com/k-bentsen/Row2Flow
 * License: BSD 3-Clause License
 */

@IsTest
private class Row2FlowSOQLTest
{
    private static Row_2_Flow_Configuration__mdt soqlConfig = Row_2_Flow_Configuration__mdt.getAll().get('SOQL_Test');
    private static Id batchJobId;
    private static Row2FlowSOQLBatchable soqlBatchRun;

    @isTest
    private static void runConfigSOQL()
    {
        Row2FlowTestUtils.insertTestRecords(5);
        soqlBatchRun = new Row2FlowSOQLBatchable(soqlConfig);

        Test.startTest();
            batchJobId = Database.executeBatch(soqlBatchRun);
        Test.stopTest();

        Row_2_Flow_Run_Result__c runResult = Row2FlowTestUtils.getResult(batchJobId);
        Assert.areEqual('Row_2_Flow_Test_Headless_Flow', runResult.Flow__c);
        Assert.areEqual('SOQL', runResult.Type__c);
        Assert.areEqual(5, runResult.Number_Success_Rows__c);
    }
}