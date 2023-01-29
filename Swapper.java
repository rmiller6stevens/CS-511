public class Swapper implements Runnable {
    private int offset;
    private Interval interval;
    private String content;
    private char[] buffer;

    public Swapper(Interval interval, String content, char[] buffer, int offset) {
        this.offset = offset;
        this.interval = interval;
        this.content = content;
        this.buffer = buffer;
    }
    @Override
    public void run() {
        char[] arr = content.toCharArray();
        for(int i = 0; i < this.interval.getY() - this.interval.getX(); i++){
            this.buffer[this.interval.getX() + i] = arr[offset + i];
        }
    }
}