public class OfflineProcessingSchedulable implements Schedulable
{
    private String interval = '15 Minutes';

    public void execute(SchedulableContext sctx)
    {
        OfflineProcessing.process(interval, sctx.getTriggerId());
    }

    public OfflineProcessingSchedulable withInterval(String interval)
    {
        this.interval = interval;
        return this;
    }
}