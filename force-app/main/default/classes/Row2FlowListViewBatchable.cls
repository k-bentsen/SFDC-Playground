/**
 * Author: Kyle Bentsen
 * GitHub: https://github.com/k-bentsen/Row2Flow
 * License: BSD 3-Clause License
 */

public class Row2FlowListViewBatchable extends Row2FlowSOQLBatchable
{
    private String listViewIdOrAPIName;

    public Row2FlowListViewBatchable(Row_2_Flow_Configuration__mdt config)
    {
        super(config);
        this.listViewIdOrAPIName = config.List_View_Id_API_Name__c;
    }

    public Row2FlowListViewBatchable(String listViewIdOrAPIName, String flowName, Map<String, String> fieldToFlowInput)
    {
        super(null, flowName, fieldToFlowInput);
        this.listViewIdOrAPIName = listViewIdOrAPIName;
        resultsHandler.getRecord().Type__c = 'List View';
    }

    protected override Database.QueryLocator generateQuery()
    {
        ListView lv = getListView();
        HttpRequest listViewDesc = new HttpRequest();
        listViewDesc.setMethod('GET');
        listViewDesc.setHeader('Content-Type', 'application/json');
        listViewDesc.setHeader('Accepts', 'application/json');
        listViewDesc.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        String descEndpoint = URL.getOrgDomainURL().toExternalForm() + '/services/data/' + getApiVersion() + '/sobjects/' + lv.SobjectType + '/listviews/' + lv.Id + '/describe';
        listViewDesc.setEndpoint(descEndpoint);
        HttpResponse resp = new Http().send(listViewDesc);
        String query = ((ListViewDescribe)JSON.deserialize(resp.getBody(), ListViewDescribe.class)).query;
        return Database.getQueryLocator(query); 
    }

    private ListView getListView()
    {
        return [SELECT Id, SObjectType FROM ListView WHERE Id =: listViewIdOrAPIName OR DeveloperName =: listViewIdOrAPIName];
    }

    @testVisible
    public class ListViewDescribe
    {
        public String query;
        public Id id;
        public String sObjectType;
    }

    private String getApiVersion()
    {
        JSONGenerator gen = JSON.createGenerator(false);
        gen.writeObject(new User(Id = UserInfo.getUserId()));
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(gen.getAsString());
        Map<String, Object> resultAttributes = (Map<String, Object>) result.get('attributes');
        String resultAttributesURL = (String) resultAttributes.get('url');
        return resultAttributesURL.substringAfter('/services/data/v').substringBefore('/');
    }
}