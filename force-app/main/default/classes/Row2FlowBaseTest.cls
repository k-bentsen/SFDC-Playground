/**
 * Author: Kyle Bentsen
 * GitHub: https://github.com/k-bentsen/Row2Flow
 * License: BSD 3-Clause License
 */

@IsTest
private class Row2FlowBaseTest
{
    @isTest
    private static void forceError()
    {
        Row2FlowTestUtils.insertTestRecords(5);
        Row2FlowBase.throwTestException = true;
        Row_2_Flow_Configuration__mdt soqlConfig = Row_2_Flow_Configuration__mdt.getAll().get('SOQL_Test');
        Row2FlowSOQLBatchable soqlBatchRun = new Row2FlowSOQLBatchable(soqlConfig);
        soqlBatchRun.saveResultFile(true);
        Id batchJobId;

        Test.startTest();
            batchJobId = Database.executeBatch(soqlBatchRun);
        Test.stopTest();

        Row_2_Flow_Run_Result__c runResult = Row2FlowTestUtils.getResult(batchJobId);
        Assert.areEqual(5, runResult.Number_Failure_Rows__c);
        ContentDocumentLink resultCDL = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId =: runResult.Id];
        List<ContentVersion> result = [SELECT VersionData FROM ContentVersion WHERE ContentDocumentId =: resultCDL.ContentDocumentId];
        String fileBody = result[0].VersionData.toString();
        Assert.isTrue(fileBody.contains('Failure Records(5)'));
        Assert.isTrue(fileBody.contains(Row2FlowTestUtils.accts[0].Id + ' => An error has occurred in flow ' + soqlConfig.Flow_API__c));
    }

    @isTest
    private static void dataConversions()
    {
        Map<String, String> data = new Map<String, String>{'Boolean' => 'false', 'Integer' => '5', 'Decimal' => '10.0', 'Date' => '2022-01-01', 'Date/Time' => '2022-01-01 00:00:00', 'String' => 'string'};
        Row2FlowBase baseInstance = new Row2FlowBase();
        Boolean convertErr = false;
        
        Test.startTest();
            for(String dataType: data.keySet()) {
                Row_2_Flow_Mapping__mdt mapping = new Row_2_Flow_Mapping__mdt();
                mapping.Data_Type__c = dataType;
                mapping.Source__c = data.get(dataType);
                try {
                    baseInstance.convertDataType(mapping);
                } catch(Exception e){
                    convertErr = true;
                }
            }
        Test.stopTest();

        Assert.isFalse(convertErr);
    }
}