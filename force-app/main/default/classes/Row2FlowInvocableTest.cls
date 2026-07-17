/**
 * Author: Kyle Bentsen
 * GitHub: https://github.com/k-bentsen/Row2Flow
 * License: BSD 3-Clause License
 */

@IsTest (SeeAllData=true) 
private class Row2FlowInvocableTest
{
    private static List<Row2FlowBase.FlowResult> flowResults;
    private static Row2FlowInvocable.Input inp = new Row2FlowInvocable.Input();
    private static Row_2_Flow_Run_Result__c runResult;
    private static Row2FlowNoConfigInvocable.Input noConfigInp = new Row2FlowNoConfigInvocable.Input();
    private static List<Row2FlowKeyValuePair> staticParamKVPs = new List<Row2FlowKeyValuePair>{new Row2FlowKeyValuePair('Pass', 'true')};

    @isTest
    private static void runReportInvocable()
    {
        inp.configName = 'Report_Test';

        Test.startTest();
            flowResults = Row2FlowInvocable.run(new List<Row2FlowInvocable.Input>{inp});
        Test.stopTest();

        runResult = Row2FlowTestUtils.getResult(flowResults[0].jobId);
        Assert.areEqual('Row_2_Flow_Test_Headless_Flow', runResult.Flow__c);
        Assert.areEqual('Report', runResult.Type__c);
        Assert.areEqual(1, runResult.Number_Success_Rows__c);
    }

    @isTest
    private static void runSOQLInvocable()
    {
        Row2FlowTestUtils.insertTestRecords(1);
        inp.config = Row2FlowBase.configQuery('SOQL_Test');

        Test.startTest();
            flowResults = Row2FlowInvocable.run(new List<Row2FlowInvocable.Input>{inp});
        Test.stopTest();

        runResult = Row2FlowTestUtils.getResult(flowResults[0].jobId);
        Assert.areEqual('Row_2_Flow_Test_Headless_Flow', runResult.Flow__c);
        Assert.areEqual('SOQL', runResult.Type__c);
        Assert.areEqual(1, runResult.Number_Success_Rows__c);
    }

    @isTest
    private static void listViewInvocable()
    {
        Row2FlowTestUtils.insertTestRecords(1);
        inp.config = Row2FlowBase.configQuery('List_View_Test');

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new Row2FlowTestUtils.ListViewDescribeMock());
            flowResults = Row2FlowInvocable.run(new List<Row2FlowInvocable.Input>{inp});
        Test.stopTest();

        runResult = Row2FlowTestUtils.getResult(flowResults[0].jobId);
        Assert.areEqual('Row_2_Flow_Test_Headless_Flow', runResult.Flow__c);
        Assert.areEqual('List View', runResult.Type__c);
        Assert.areEqual(1, runResult.Number_Success_Rows__c);
    }

    @isTest
    private static void runInvocableInactive()
    {
        Row_2_Flow_Configuration__mdt inactiveConfig = new Row_2_Flow_Configuration__mdt();
        inactiveConfig.Active__c = false;
        inp.config = inactiveConfig;

        Test.startTest();
            flowResults = Row2FlowInvocable.run(new List<Row2FlowInvocable.Input>{inp});
        Test.stopTest();

        Assert.isFalse(flowResults[0].success);
        Assert.areEqual('Configuration Inactive', flowResults[0].failureMsg);
    }

    @IsTest
    private static void noConfigReport()
    {
        noConfigInp.sourceType = 'Report';
        noConfigInp.flowName = 'Row_2_Flow_Test_Headless_Flow';
        noConfigInp.inputParams = new List<Row2FlowKeyValuePair>{new Row2FlowKeyValuePair('ACCOUNT.NAME', 'CustName')};
        noConfigInp.staticParams = staticParamKVPs;
        noConfigInp.reportIdOrAPIName = 'Row_2_Flow_Test_Report';
        noConfigInp.uniqueColumnHeader = 'ACCOUNT.NAME';
        noConfigInp.saveResultsRec = true;

        Test.startTest();
            flowResults = Row2FlowNoConfigInvocable.run(new List<Row2FlowNoConfigInvocable.Input>{noConfigInp});
        Test.stopTest();

        runResult = Row2FlowTestUtils.getResult(flowResults[0].jobId);
        Assert.areEqual('Row_2_Flow_Test_Headless_Flow', runResult.Flow__c);
        Assert.areEqual('Report', runResult.Type__c);
        Assert.areEqual(1, runResult.Number_Success_Rows__c);
    }

    @IsTest
    private static void noConfigSOQLReport()
    {
        Row2FlowTestUtils.insertTestRecords(1);
        noConfigInp.sourceType = 'SOQL';
        noConfigInp.flowName = 'Row_2_Flow_Test_Headless_Flow';
        noConfigInp.inputParams = new List<Row2FlowKeyValuePair>{new Row2FlowKeyValuePair('Name', 'CustName')};
        noConfigInp.staticParams = staticParamKVPs;
        noConfigInp.queryStr = 'Account WHERE Name = \'Row2Flow Test Account\'';
        noConfigInp.saveResultsRec = true;

        Test.startTest();
            flowResults = Row2FlowNoConfigInvocable.run(new List<Row2FlowNoConfigInvocable.Input>{noConfigInp});
        Test.stopTest();

        runResult = Row2FlowTestUtils.getResult(flowResults[0].jobId);
        Assert.areEqual('Row_2_Flow_Test_Headless_Flow', runResult.Flow__c);
        Assert.areEqual('SOQL', runResult.Type__c);
        Assert.areEqual(1, runResult.Number_Success_Rows__c);
    }

    @IsTest
    private static void noConfigListViewReport()
    {
        Row2FlowTestUtils.insertTestRecords(1);
        noConfigInp.sourceType = 'List View';
        noConfigInp.flowName = 'Row_2_Flow_Test_Headless_Flow';
        noConfigInp.inputParams = new List<Row2FlowKeyValuePair>{new Row2FlowKeyValuePair('Name', 'CustName')};
        noConfigInp.staticParams = staticParamKVPs;
        noConfigInp.listViewIdOrAPIName = 'Row_2_Flow_Test_List_View';
        noConfigInp.saveResultsRec = true;

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new Row2FlowTestUtils.ListViewDescribeMock());
            flowResults = Row2FlowNoConfigInvocable.run(new List<Row2FlowNoConfigInvocable.Input>{noConfigInp});
        Test.stopTest();

        runResult = Row2FlowTestUtils.getResult(flowResults[0].jobId);
        Assert.areEqual('Row_2_Flow_Test_Headless_Flow', runResult.Flow__c);
        Assert.areEqual('List View', runResult.Type__c);
        Assert.areEqual(1, runResult.Number_Success_Rows__c);
    }
}