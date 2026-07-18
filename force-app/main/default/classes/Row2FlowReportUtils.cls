/**
 * Author: Kyle Bentsen
 * GitHub: https://github.com/k-bentsen/Row2Flow
 * License: BSD 3-Clause License
 */

public with sharing class Row2FlowReportUtils
{
    public static String printReportColumnsById(Id reportId)
    {
        Reports.ReportDescribeResult rptDesc = Reports.ReportManager.describeReport(reportId);
        Reports.ReportMetadata rm = rptDesc.getReportMetadata();
        Map<String,Reports.DetailColumn> detailColumns = rptDesc.getReportExtendedMetadata().getDetailColumnInfo();
        String output = '\n';
        for(Reports.DetailColumn detailCol: detailColumns.values()){
            output += detailCol.getLabel() + ' => ' + detailCol.getName() + '\n';
        }
        return output;
    }

    public static String printReportColumns(String reportAPIName)
    {
        Id reportId = [SELECT Id FROM Report WHERE DeveloperName = :reportAPIName].Id;
        return printReportColumnsById(reportId);
    }
}