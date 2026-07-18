/**
 * Author: Kyle Bentsen
 * GitHub: https://github.com/k-bentsen/Row2Flow
 * License: BSD 3-Clause License
 */

public class Row2FlowReportBatchable extends Row2FlowBase implements Database.Batchable<Reports.ReportDetailRow>, 
                                                                     Database.AllowsCallouts,
                                                                     Database.Stateful,
                                                                     Database.RaisesPlatformEvents
{
    private String reportIdOrAPIName;
    private Reports.ReportDescribeResult rptDesc;
    private Reports.ReportMetadata rm;
    private String uniqueColumnHeader;
    private List<SObject> rowsAsSObjs;

    private Map<String, String> convertColumnToFieldErrs;

    public Row2FlowReportBatchable(String reportIdOrAPIName, String uniqueColumnHeader, String flowName, Map<String, String> fieldToFlowInput)
    {
        super(flowName, fieldToFlowInput);
        this.reportIdOrAPIName = reportIdOrAPIName;
        this.uniqueColumnHeader = uniqueColumnHeader;
        resultsHandler.getRecord().Type__c = 'Report';
    }

    public Row2FlowReportBatchable(Row_2_Flow_Configuration__mdt config)
    {
        super(config);
        this.reportIdOrAPIName = config.Report_Id_API_Name__c;
        this.uniqueColumnHeader = config.Unique_Column_Header__c;
    }

    public Row2FlowReportBatchable withStaticFlowParams(Map<String, Object> staticFlowParamValues)
    {
        addStaticFlowParams(staticFlowParamValues);
        return this;
    }

    public Iterable<Reports.ReportDetailRow> start(Database.BatchableContext bc)
    {
        Id reportId;
        if(this.reportIdOrAPIName.startsWith('00O')) {
            reportId = this.reportIdOrAPIName;
        } else {
            reportId = [SELECT Id FROM Report WHERE DeveloperName = :this.reportIdOrAPIName].Id;
        }
        rptDesc = Reports.ReportManager.describeReport(reportId);
        rm = rptDesc.getReportMetadata();
        setStartTime();
        resultsHandler.getRecord().Batch_Job_Id__c = bc.getJobId();
        return new Row2FlowReportConvert.ReportRowIterator(reportId, uniqueColumnHeader);
    }

    public void execute(Database.BatchableContext bc, List<Reports.ReportDetailRow> reportRows)
    {
        String serializedRows = JSON.serialize(reportRows);
        resultsHandler.initializeRowKeys();
        runFlowPerRow(reportRows);
    }

    public void finish(Database.BatchableContext bc)
    {   
        if(generateResultsRec) {
            resultsHandler.saveResultRecord();
        }
    }

    private void runFlowPerRow(List<Reports.ReportDetailRow> reportRows)
    {
        for(Map<String, Object> objMap: convertRows(reportRows))
        {
            Map<String, Object> flowParams = new Map<String, Object>(staticFlowParamValues);
            for(String sourceField: fieldToFlowInput.keySet())
            {
                Object val = objMap.get(sourceField);
                flowParams.put(fieldToFlowInput.get(sourceField), val);
            }
            processFlow(flowParams);
        }
    }

    private List<Map<String, Object>> convertRows(List<Reports.ReportDetailRow> reportRows)
    {
        List<Map<String, Object>> convertedRows = new List<Map<String, Object>>();
        List<String> columns = rm.getDetailColumns();
        Map<String,Reports.DetailColumn> detailColumns = rptDesc.getReportExtendedMetadata().getDetailColumnInfo();
        /*if(sObjType != NULL && sObjTypeAPI == NULL){
            sObjTypeAPI = sObjType.getDescribe().getName();
        }*/
        
        for(Reports.ReportDetailRow row: reportRows)
        {
            SObject sObj;
            List<Reports.ReportDataCell> dataCells = row.getDataCells();
            Map<String, Object> rowAsObj = new Map<String, Object>();
            for(Integer i = 0; i < columns.size(); i++)
            {
                String column = columns[i];
                Reports.ReportDataCell cell = dataCells[i];
                Reports.DetailColumn detailColumn = detailColumns.get(column);
                Reports.ColumnDataType columnDT = detailColumn.getDataType();
                Object cellValForMap = null;
                Object cellVal = cell.getValue();
                if(columnDT == Reports.ColumnDataType.CURRENCY_DATA)
                {
                    Reports.ReportCurrency currencyData = (Reports.ReportCurrency) cellVal;
                    if(currencyData != NULL){
                        cellValForMap = currencyData.getAmount();
                    }
                }
                else if(columnTypesForValue.contains(columnDT)){
                    cellValForMap = cellVal;
                }
                else{
                    cellValForMap = cell.getLabel();
                }
                rowAsObj.put(column, cellValForMap);
                /* to be implemented for passing record collection to flow
                if(isCollection){
                    try{
                        sObj.put(convertReservedColumnHeaders(column), cellValForMap);
                    } catch(SObjectException sObjEx){
                        if(convertColumnToFieldErrs == NULL){
                            convertColumnToFieldErrs = new Map<String, String>();
                        }
                        convertColumnToFieldErrs.put(column, sObjEx.getMessage());
                    }
                }*/
                if(column == uniqueColumnHeader){
                    resultsHandler.addRowKey(String.valueof(cellValForMap));
                }
            }
            convertedRows.add(rowAsObj);
        }
        return convertedRows;
    }

    /* to be implemented for passing record collection to flow
    private static String convertReservedColumnHeaders(String reportColumn)
    {
        if(reservedColumnHeaders.containsKey(reportColumn)){
            return reservedColumnHeaders.get(reportColumn);
        }
        String returnColumn = reportColumn;
        if(returnColumn.toUpperCase().startsWith('CUST_')){
            returnColumn = returnColumn.toUpperCase().removeStart('CUST_');
        }
        if(returnColumn.toUpperCase().startsWith(sObjTypeAPI.toUpperCase())){
            returnColumn = returnColumn.toUpperCase().removeStart(sObjTypeAPI.toUpperCase()).removeStart('.').removeStart('_');
        }
        return returnColumn;
    }*/

    private static String sObjTypeAPI;

    private static final Map<String, String> reservedColumnHeaders = new Map<String, String>{
        'USERS.NAME' => 'OwnerId',
        'CREATED_DATE' => 'CreatedDate',
        'LAST_UPDATE' => 'LastModifiedDate',
        'CREATED' => 'CreatedById',
        'LAST_UPDATE_BY' => 'LastModifiedById',
        'DUE_DATE'=> 'LastActivityDate',
        'PARENT_ID' => 'ParentId',
        'ACCOUNT_NUMER' => 'AccountNumber'
    };

    private static final Set<Reports.ColumnDataType> columnTypesForValue = new Set<Reports.ColumnDataType>{
        Reports.ColumnDataType.BOOLEAN_DATA,
        Reports.ColumnDataType.DATE_DATA,
        Reports.ColumnDataType.DATETIME_DATA,
        Reports.ColumnDataType.INT_DATA,
        Reports.ColumnDataType.DOUBLE_DATA,
        Reports.ColumnDataType.PERCENT_DATA,
        Reports.ColumnDataType.ID_DATA
    };
}