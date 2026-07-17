/**
 * Author: Kyle Bentsen
 * GitHub: https://github.com/k-bentsen/Row2Flow
 * License: BSD 3-Clause License
 */

public virtual class Row2FlowBase
{
    protected String flowName;
    protected Map<String, String> fieldToFlowInput = new Map<String, String>();
    protected Map<String, Object> staticFlowParamValues = new Map<String, Object>();

    protected Schema.SObjectType sObjType;

    protected Boolean generateResultsRec = false;
    protected Row2FlowResultsHandler resultsHandler;

    protected String jobName = 'Anonymous Row 2 Flow Job';

    public Row2FlowBase() 
    {
        this.flowName = null;
    }
    
    public Row2FlowBase(String flowName, Map<String, String> fieldToFlowInput)
    {
        this.flowName = flowName;
        this.fieldToFlowInput = fieldToFlowInput;
        this.resultsHandler = new Row2FlowResultsHandler(new Row_2_Flow_Run_Result__c(Flow__c = this.flowName));
    }

    public Row2FlowBase(Row_2_Flow_Configuration__mdt config) 
    {
        this.flowName = config.Flow_API__c;
        List<Row_2_Flow_Mapping__mdt> configInputs = [SELECT Source__c, Target__c, Type__c, Data_Type__c FROM Row_2_Flow_Mapping__mdt WHERE Row_2_Flow_Configuration__c = :config.Id AND Active__c = TRUE];
        for(Row_2_Flow_Mapping__mdt mapping: configInputs)
        {
            if(mapping.Type__c == 'Static')
            {
                Object val = convertDataType(mapping);
                staticFlowParamValues.put(mapping.Target__c, val);
            } else if(mapping.Type__c == 'Source Value'){
                fieldToFlowInput.put(mapping.Source__c, mapping.Target__c);
            }
        }

        this.resultsHandler = new Row2FlowResultsHandler(new Row_2_Flow_Run_Result__c(Flow__c = this.flowName, Configuration_Name__c = config.DeveloperName, Type__c = config.Source_Type__c));
        if(config.Generate_Results_Record__c) {
            saveResultFile(config.Generate_Per_Run_Results_File__c);
        }
    }

    public void addStaticFlowParams(Map<String, Object> staticFlowParamValues)
    {
        this.staticFlowParamValues.putAll(staticFlowParamValues);
    }

    public void saveResultFile(Boolean generatePerRunFile)
    {
        this.generateResultsRec = true;
        if(generatePerRunFile) {
            this.resultsHandler.setGeneratePerRunResultFile();
        }
    }

    protected virtual FlowResult runFlow(Flow.Interview flowToRun)
    {
        return defaultFlowRun(flowToRun);
    }

    @testVisible
    private FlowResult defaultFlowRun(Flow.Interview flowToRun)
    {
        FlowResult fr = new FlowResult();
        try {
            flowToRun.start();
            if(Test.isRunningTest() && throwTestException) {
                throw new FlowException('An error has occurred in flow ' + flowName);
            }
            fr.success = true;
        } catch (Exception e) {
            fr.failureMsg = e.getMessage();
        }
        return fr;
    }

    protected void processFlow(Map<String, Object> flowParams)
    {
        Flow.Interview flowInstance = Flow.Interview.createInterview(flowName, flowParams);
        Row2FlowBase.FlowResult fr = runFlow(flowInstance);
        resultsHandler.handleFlowResults(fr);
    }

    @testVisible
    protected Object convertDataType(Row_2_Flow_Mapping__mdt mapping)
    {
        Object val = null;
        switch on mapping.Data_Type__c
        {
            when 'Boolean' {
                val = Boolean.valueOf(mapping.Source__c);
            }
            when 'Integer' {
                val = Integer.valueOf(mapping.Source__c);
            }
            when 'Decimal' {
                val = Decimal.valueOf(mapping.Source__c);
            }
            when 'Date' {
                val = Date.valueOf(mapping.Source__c);
            }
            when 'Date/Time' {
                val = Datetime.valueOf(mapping.Source__c);
            }
            when 'String' {
                val = String.valueOf(mapping.Source__c);
            }
        }
        return val;
    }

    protected void setStartTime()
    {
        this.resultsHandler.getRecord().Start_Time__c = System.NOW();
    }

    public static Row_2_Flow_Configuration__mdt configQuery(String configName)
    {
        return [SELECT DeveloperName, MasterLabel, Active__c, Batch_Size__c, Source_Type__c, Flow_API__c, Report_Id_API_Name__c, Unique_Column_Header__c, SOQL_Query_Filter_Conditions__c, List_View_Id_API_Name__c, Generate_Results_Record__c, Generate_Per_Run_Results_File__c FROM Row_2_Flow_Configuration__mdt WHERE DeveloperName = :configName];
    }

    public class FlowResult
    {
        @InvocableVariable
        public Boolean success = false;
        @InvocableVariable
        public Row_2_Flow_Configuration__mdt config;
        @InvocableVariable
        public String failureMsg;
        @InvocableVariable
        public String jobId;
    }

    @testVisible
    private static Boolean throwTestException = false;
}