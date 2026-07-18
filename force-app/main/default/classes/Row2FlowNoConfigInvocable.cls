/**
 * Author: Kyle Bentsen
 * GitHub: https://github.com/k-bentsen/Row2Flow
 * License: BSD 3-Clause License
 */

public class Row2FlowNoConfigInvocable
{
    public class Input
    {
        @InvocableVariable (required = true)
        public String flowName;
        @InvocableVariable
        public String sourceType;
        @InvocableVariable
        public String reportIdOrAPIName;
        @InvocableVariable
        public String uniqueColumnHeader;
        @InvocableVariable
        public String queryStr;
        @InvocableVariable
        public String listViewIdOrAPIName;
        @InvocableVariable
        public Integer batchSize = 1;
        @InvocableVariable
        public Boolean saveResultsRec = false;
        @InvocableVariable
        public Boolean generatePerResultFile = false;
        @InvocableVariable (required = true)
        public List<Row2FlowKeyValuePair> inputParams = new List<Row2FlowKeyValuePair>();
        @InvocableVariable
        public List<Row2FlowKeyValuePair> staticParams = new List<Row2FlowKeyValuePair>();
    }

    @InvocableMethod
    public static List<Row2FlowBase.FlowResult> run(List<Input> inputs)
    {
        List<Row2FlowBase.FlowResult> results = new List<Row2FlowBase.FlowResult>();
        for(Input input: inputs)
        {
            Row2FlowBase.FlowResult fr = new Row2FlowBase.FlowResult();
            results.add(fr);

            Map<String, String> inputParams = new Map<String, String>();
            
            for(Row2FlowKeyValuePair kvp: input.inputParams) {
                inputParams.put(kvp.key, kvp.value);
            }
            
            switch on input.sourceType
            {
                when 'Report' {
                    Row2FlowReportBatchable reportRun = new Row2FlowReportBatchable(input.reportIdOrAPIName, input.uniqueColumnHeader, input.flowName, inputParams);
                    mapInputsToBatchable(reportRun, input);
                    fr.jobId = Database.executeBatch(reportRun, input.batchSize);
                }
                when 'SOQL' {
                    Row2FlowSOQLBatchable soqlRun = new Row2FlowSOQLBatchable(input.queryStr, input.flowName, inputParams);
                    mapInputsToBatchable(soqlRun, input);
                    fr.jobId = Database.executeBatch(soqlRun, input.batchSize);
                }
                when 'List View' {
                    Row2FlowListViewBatchable listViewRun = new Row2FlowListViewBatchable(input.listViewIdOrAPIName, input.flowName, inputParams);
                    mapInputsToBatchable(listViewRun, input);
                    fr.jobId = Database.executeBatch(listViewRun, input.batchSize);
                }
            }
            fr.success = true;
        }
        return results;
    }

    private static void mapInputsToBatchable(Row2FlowBase batchJob, Input input)
    {
        Map<String, String> staticParams = new Map<String, String>();
        if(!input.staticParams.isEmpty())
        {
            for(Row2FlowKeyValuePair kvp: input.staticParams) {
                staticParams.put(kvp.key, kvp.value);
            }
            batchJob.addStaticFlowParams(staticParams);
        }
        if(input.saveResultsRec) {
            batchJob.saveResultFile(input.generatePerResultFile);
        }
    }
}