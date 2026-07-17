/**
 * Author: Kyle Bentsen
 * GitHub: https://github.com/k-bentsen/Row2Flow
 * License: BSD 3-Clause License
 */

@isTest
private class Row2FlowListViewTest
{
    private static Row_2_Flow_Configuration__mdt listViewConfig = Row_2_Flow_Configuration__mdt.getAll().get('List_View_Test');
    private static Id batchJobId;
    private static Row2FlowListViewBatchable listViewBatchRun;
    

    @isTest
    private static void listViewRun()
    {
        Row2FlowTestUtils.insertTestRecords(1);
        listViewBatchRun = new Row2FlowListViewBatchable(listViewConfig);

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new Row2FlowTestUtils.ListViewDescribeMock());
            batchJobId =Database.executeBatch(listViewBatchRun);
        Test.stopTest();

        Row_2_Flow_Run_Result__c runResult = Row2FlowTestUtils.getResult(batchJobId);
        Assert.areEqual('Row_2_Flow_Test_Headless_Flow', runResult.Flow__c);
        Assert.areEqual('List View', runResult.Type__c);
        Assert.areEqual(1, runResult.Number_Success_Rows__c);
    }
}