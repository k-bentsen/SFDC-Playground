/**
 * Author: Kyle Bentsen
 * GitHub: https://github.com/k-bentsen/Row2Flow
 * License: BSD 3-Clause License
 */

public class Row2FlowInvocable
{
    public class Input
    {
        @InvocableVariable
        public Row_2_Flow_Configuration__mdt config;
        @InvocableVariable
        public String configName;
    }

    @InvocableMethod (Label='Row2Flow')
    public static List<Row2FlowBase.FlowResult> run(List<Input> inputs)
    {
        List<Row2FlowBase.FlowResult> results = new List<Row2FlowBase.FlowResult>();
        for(Input input: inputs)
        {
            Row2FlowBase.FlowResult fr = new Row2FlowBase.FlowResult();
            results.add(fr);
            if(input.config == null && inputs.size() == 1) {
                input.config = Row2FlowBase.configQuery(input.configName);
            }
            fr.config = input.config;
            if(!input.config.Active__c)
            {
                fr.failureMsg = 'Configuration Inactive';
                continue;
            }
            switch on input.config.Source_Type__c
            {
                when 'Report' {
                    Row2FlowReportBatchable flowBatchRun = new Row2FlowReportBatchable(input.config);
                    fr.jobId = Database.executeBatch(flowBatchRun, Integer.valueOf(input.config.Batch_Size__c));
                }
                when 'SOQL' {
                    Row2FlowSOQLBatchable flowBatchRun = new Row2FlowSOQLBatchable(input.config);
                    fr.jobId = Database.executeBatch(flowBatchRun, Integer.valueOf(input.config.Batch_Size__c));
                }
                when 'List View' {
                    Row2FlowListViewBatchable flowBatchRun = new Row2FlowListViewBatchable(input.config);
                    fr.jobId = Database.executeBatch(flowBatchRun, Integer.valueOf(input.config.Batch_Size__c));
                }
            }
            fr.success = true;
        }
        return results;
    }
}