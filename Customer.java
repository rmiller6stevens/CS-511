import java.util.Arrays;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;


public class Customer implements Runnable {
    private Bakery bakery;
    private Random rnd;
    private List<BreadType> shoppingCart;
    private int shopTime;
    private int checkoutTime;

    /**
     * Initialize a customer object and randomize its shopping cart
     */
    public Customer(Bakery bakery) {
        this.rnd = new Random();
       this.bakery = bakery;
       this.shoppingCart = new ArrayList<BreadType>();
       this.fillShoppingCart();
       this.shopTime = 1 + rnd.nextInt(2000); //Max 2 seconds
       this.checkoutTime = 1 + rnd.nextInt(2000); //Max 2 seconds
    }

    /**
     * Run tasks for the customer
     */
    public void run() {
        System.out.println("Customer " + hashCode() + " begins shopping.");
    for(BreadType x : this.shoppingCart){ //putting bread in cart
        switch(x){
            case RYE:
                try{
                    this.bakery.rye.acquire();
                        this.bakery.takeBread(BreadType.RYE);
                        System.out.println("Customer " + hashCode() + " takes Rye Loaf.");
                    this.bakery.rye.release();
                    continue;
                } catch (Exception e){
                    System.out.println("Erorr: " + e);
                }
            case WONDER:
                try{
                    this.bakery.wonder.acquire();
                        this.bakery.takeBread(BreadType.WONDER);
                        System.out.println("Customer " + hashCode() + " takes Wonder Loaf.");
                    this.bakery.wonder.release();
                    continue;
                } catch (Exception e){
                    System.out.println("Erorr: " + e);
                }
            case SOURDOUGH:
                try{
                    this.bakery.sour.acquire();
                        this.bakery.takeBread(BreadType.SOURDOUGH);
                        System.out.println("Customer " + hashCode() + " takes Sourdough Loaf.");
                    this.bakery.sour.release();
                    continue;
                } catch (Exception e){
                    System.out.println("Erorr: " + e);
                }
            }
        }
        try{
            //Thread.sleep(this.shopTime); //sleep before for shop time
            this.bakery.register.acquire();
                //Thread.sleep(this.checkoutTime); //sleep for cashier
                this.bakery.updateS.acquire();
                    this.bakery.addSales(this.getItemsValue());
                    System.out.println("Customer " + hashCode() + " buys bread.");
                this.bakery.updateS.release();
            this.bakery.register.release();
        } catch (Exception e){
            System.out.println("Erorr: " + e);
        }
        System.out.println("Customer " + hashCode() + " finished shopping.");
    }

    /**
     * Return a string representation of the customer
     */
    public String toString() {
        return "Customer " + hashCode() + ": shoppingCart=" + Arrays.toString(shoppingCart.toArray()) + ", shopTime=" + shopTime + ", checkoutTime=" + checkoutTime;
    }

    /**
     * Add a bread item to the customer's shopping cart
     */
    private boolean addItem(BreadType bread) {
        // do not allow more than 3 items, chooseItems() does not call more than 3 times
        if (shoppingCart.size() >= 3) {
            return false;
        }
        shoppingCart.add(bread);
        return true;
    }

    /**
     * Fill the customer's shopping cart with 1 to 3 random breads
     */
    private void fillShoppingCart() {
        int itemCnt = 1 + rnd.nextInt(3);
        while (itemCnt > 0) {
            addItem(BreadType.values()[rnd.nextInt(BreadType.values().length)]);
            itemCnt--;
        }
    }

    /**
     * Calculate the total value of the items in the customer's shopping cart
     */
    private float getItemsValue() {
        float value = 0;
        for (BreadType bread : shoppingCart) {
            value += bread.getPrice();
        }
        return value;
    }
}