/**
 * Author: Kyle Bentsen
 * GitHub: https://github.com/k-bentsen/Row2Flow
 * License: BSD 3-Clause License
 */

public with sharing class Row2FlowResultsHandler
{
    private Row_2_Flow_Run_Result__c runResult;
    private Boolean generatePerRunResultFile = false;
    private Set<String> successRows = new Set<String>();
    private Map<String, String> failureRows = new Map<String, String>();
    private Set<String> allRowKeys;
    private DateTime startTime;

    public Row2FlowResultsHandler(Row_2_Flow_Run_Result__c runResult)
    {
        this.runResult = runResult;
    }

    public void handleFlowResults(Row2FlowBase.FlowResult fr)
    {
        if(fr.success) {
            successRows.addAll(allRowKeys);
        } else {
            for(String recVal: allRowKeys) {
                failureRows.put(recVal, fr.failureMsg);
            }
        }
    }

    public void saveResultRecord()
    {
        runResult.End_Time__c = System.NOW();
        runResult.Number_Success_Rows__c = successRows.size();
        runResult.Number_Failure_Rows__c = failureRows.size();
        insert runResult;
        if(generatePerRunResultFile) {
            saveResultFile();
        }
    }

    private void saveResultFile()
    {
        ContentVersion resultFile = new ContentVersion(Title = 'Per Run Details', VersionData = Blob.valueOf(generateResultsFileBody()), PathOnClient = 'Per Run Details.txt');
        insert resultFile;
        resultFile = [Select ContentDocumentId from ContentVersion WHERE id = :resultFile.Id];
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = resultFile.ContentDocumentId;
        cdl.ShareType = 'I';
        cdl.LinkedEntityId = runResult.Id;
        insert cdl;
    }

    public void setGeneratePerRunResultFile()
    {
        generatePerRunResultFile = true;
    }

    public void initializeRowKeys()
    {
        allRowKeys = new Set<String>();
    }

    public void addRowKey(String rowKey)
    {
        allRowKeys.add(rowKey);
    }

    public Row_2_Flow_Run_Result__c getRecord()
    {
        return this.runResult;
    }

    private String generateResultsFileBody()
    {
        String resultStr = 'Success Records(' + successRows.size() +'):\n';
        for(String rec: successRows){
            resultStr += rec + '\n';
        }
        resultStr += '\nFailure Records(' + failureRows.size() +'):\n';
        for(String rec: failureRows.keySet()){
            resultStr += rec + ' => ' + failureRows.get(rec) + '\n';
        }
        return resultStr;
    }
}