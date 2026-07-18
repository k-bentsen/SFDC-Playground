/**
 * Author: Kyle Bentsen
 * GitHub: https://github.com/k-bentsen/Row2Flow
 * License: BSD 3-Clause License
 */

@IsTest
public class Row2FlowTestUtils
{
    public static List<Row2FlowBase.FlowResult> flowResults;
    public static Row_2_Flow_Configuration__mdt testConfig
    {
        get
        {
            if (testConfig == NULL) {
                testConfig = Row2FlowBase.configQuery('Config_Test_1');
            }
            return testConfig;
        }
        private set;
    }
    public static List<Account> accts;

    public static void insertTestRecords(Integer numRecs)
    {
        accts = new List<Account>();
        for(Integer i = 0; i < numRecs; i++) {
            accts.add(new Account(Name = 'Row2Flow Test Account', AnnualRevenue = 100));
        }
        insert accts;
    }

    public class ListViewDescribeMock implements HttpCalloutMock
    {
        final String sampleResponseStr = '{"columns":[{"ascendingLabel":"Z-A","descendingLabel":"A-Z","fieldNameOrPath":"Name","hidden":false,"label":"Account Name","searchable":true,"selectListItem":"Name","sortDirection":"ascending","sortIndex":0,"sortable":true,"type":"string"},{"ascendingLabel":"Z-A","descendingLabel":"A-Z","fieldNameOrPath":"Site","hidden":false,"label":"Account Site","searchable":true,"selectListItem":"Site","sortDirection":null,"sortIndex":null,"sortable":true,"type":"string"},{"ascendingLabel":"Z-A","descendingLabel":"A-Z","fieldNameOrPath":"BillingState","hidden":false,"label":"Billing State/Province","searchable":true,"selectListItem":"BillingState","sortDirection":null,"sortIndex":null,"sortable":true,"type":"string"},{"ascendingLabel":"9-0","descendingLabel":"0-9","fieldNameOrPath":"Phone","hidden":false,"label":"Phone","searchable":true,"selectListItem":"Phone","sortDirection":null,"sortIndex":null,"sortable":true,"type":"phone"},{"ascendingLabel":"Low to High","descendingLabel":"High to Low","fieldNameOrPath":"Type","hidden":false,"label":"Type","searchable":true,"selectListItem":"toLabel(Type)","sortDirection":null,"sortIndex":null,"sortable":true,"type":"picklist"},{"ascendingLabel":"Z-A","descendingLabel":"A-Z","fieldNameOrPath":"Owner.Alias","hidden":false,"label":"Account Owner Alias","searchable":false,"selectListItem":"Owner.Alias","sortDirection":null,"sortIndex":null,"sortable":true,"type":"string"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"Id","hidden":true,"label":"Account ID","searchable":false,"selectListItem":"Id","sortDirection":null,"sortIndex":null,"sortable":false,"type":"id"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"CreatedDate","hidden":true,"label":"Created Date","searchable":false,"selectListItem":"CreatedDate","sortDirection":null,"sortIndex":null,"sortable":false,"type":"datetime"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"LastModifiedDate","hidden":true,"label":"Last Modified Date","searchable":false,"selectListItem":"LastModifiedDate","sortDirection":null,"sortIndex":null,"sortable":false,"type":"datetime"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"SystemModstamp","hidden":true,"label":"System Modstamp","searchable":false,"selectListItem":"SystemModstamp","sortDirection":null,"sortIndex":null,"sortable":false,"type":"datetime"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"Owner.Id","hidden":true,"label":"User ID","searchable":false,"selectListItem":"Owner.Id","sortDirection":null,"sortIndex":null,"sortable":false,"type":"id"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"OwnerId","hidden":true,"label":"Owner ID","searchable":false,"selectListItem":"OwnerId","sortDirection":null,"sortIndex":null,"sortable":false,"type":"reference"}],"id":"00Bam000002kYjt","orderBy":[{"fieldNameOrPath":"Name","nullsPosition":"first","sortDirection":"ascending"},{"fieldNameOrPath":"Id","nullsPosition":"first","sortDirection":"ascending"}],"query":"SELECT Name, Site, BillingState, Phone, toLabel(Type), Owner.Alias, Id, CreatedDate, LastModifiedDate, SystemModstamp, Owner.Id, OwnerId FROM Account WHERE Name = \'Row2Flow Test Account\' ORDER BY Name ASC NULLS FIRST, Id ASC NULLS FIRST","relatedEntityId":null,"scope":"everything","scopeEntityId":null,"sobjectType":"Account","whereCondition":{"field":"Name","operator":"equals","values":["\'Row2Flow Test Account\'"]}}';
        
        public HttpResponse respond(HttpRequest req)
        {
            HttpResponse resp = new HttpResponse();
            resp.setBody(sampleResponseStr);
            return resp;
        }
    }

    public static Row_2_Flow_Run_Result__c getResult(Id batchJobId)
    {
        return [SELECT Id, Flow__c, Type__c, Number_Success_Rows__c, Number_Failure_Rows__c, Configuration_Name__c FROM Row_2_Flow_Run_Result__c WHERE Batch_Job_Id__c =: batchJobId];
    }
}