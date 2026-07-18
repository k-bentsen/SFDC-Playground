/**
 * Author: Kyle Bentsen
 * GitHub: https://github.com/k-bentsen/Row2Flow
 * License: BSD 3-Clause License
 */

public class Row2FlowKeyValuePair 
{
    @AuraEnabled
    public String key;
    @AuraEnabled
    public String value;
    @AuraEnabled
    public String dataType;

    public Row2FlowKeyValuePair(String key, String value)
    {
        this.key = key;
        this.value = value;
    }
}