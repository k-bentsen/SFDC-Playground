/**
 * Author: Kyle Bentsen
 * GitHub: https://github.com/k-bentsen/Row2Flow
 * License: BSD 3-Clause License
 */

@IsTest (SeeAllData=true)
private class Row2FlowReportTest
{
    private static final Report testReport = [SELECT Id FROM Report WHERE DeveloperName = 'Row_2_Flow_Test_Report'];
    private static Id batchJobId;
    private static Row_2_Flow_Configuration__mdt reportConfig = Row_2_Flow_Configuration__mdt.getAll().get('Report_Test');
    private static Row2FlowReportBatchable reportBatchRun;
    private static Row_2_Flow_Run_Result__c runResult;

    @isTest
    private static void runReportBase()
    {
        Row2FlowTestUtils.insertTestRecords(1);
        reportBatchRun = new Row2FlowReportBatchable('Row_2_Flow_Test_Report', 'ACCOUNT.NAME', 'Row_2_Flow_Test_Headless_Flow', new Map<String, String> {'StaticTextInput' => 'Default'})
            .withStaticFlowParams(new Map<String, Object>{'Pass' => true});
        reportBatchRun.saveResultFile(false);
        
        Test.startTest();
            batchJobId = Database.executeBatch(reportBatchRun);
        Test.stopTest();

        runResult = Row2FlowTestUtils.getResult(batchJobId);
        Assert.areEqual('Row_2_Flow_Test_Headless_Flow', runResult.Flow__c);
        Assert.areEqual('Report', runResult.Type__c);
        Assert.areEqual(1, runResult.Number_Success_Rows__c);
    }

    @isTest
    private static void runReportFromConfig()
    {
        Row2FlowTestUtils.insertTestRecords(1);
        reportConfig = Row2FlowBase.configQuery('Report_Test');
        reportConfig.Report_Id_API_Name__c = testReport.Id;
        reportBatchRun = new Row2FlowReportBatchable(reportConfig);

        Test.startTest();
            batchJobId = Database.executeBatch(reportBatchRun);
        Test.stopTest();

        runResult = Row2FlowTestUtils.getResult(batchJobId);
        Assert.areEqual('Report_Test', runResult.Configuration_Name__c);
        Assert.areEqual('Report', runResult.Type__c);
    }

    @isTest 
    private static void printColumnHeaders()
    {
        Test.startTest();
            String output = Row2FlowReportUtils.printReportColumnsbyId(testReport.Id);
        Test.stopTest();

        Assert.isTrue(output.contains('ACCOUNT.NAME'));
    }

    @isTest 
    private static void printColumnHeadersByAPIName()
    {
        Test.startTest();
            String output = Row2FlowReportUtils.printReportColumns('Row_2_Flow_Test_Report');
        Test.stopTest();

        Assert.isTrue(output.contains('ACCOUNT.NAME'));
    }
}