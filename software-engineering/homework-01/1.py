class OrderProcessor:
    def __init__(self):
        self.orders = []

    def _verify_user(self, user_id):
        if user_id not in ["U001", "U002", "U003"]:
            raise ValueError("Invalid user ID.")

    def _calculate_total_price(self, items):
        total_price = 0
        for item in items:
            if item["price"] < 0:
                raise ValueError("Item price cannot be negative.")
            if item["quantity"] < 0:
                raise ValueError("Item quantity cannot be negative.")
            total_price += item["price"] * item["quantity"]
        return total_price

    def _store_order(self, user_id, items, total_price):
        self.orders.append({
            "user_id": user_id,
            "items": items,
            "total_price": total_price,
        })

    def _send_notification(self, user_id, total_price):
        print(f"Email sent to user {user_id}: Your order of {total_price} is confirmed")

    def process_order(self, user_id, items):
        self._verify_user(user_id)
        total_price = self._calculate_total_price(items)
        self._store_order(user_id, items, total_price)
        self._send_notification(user_id, total_price)
        return total_price


processor = OrderProcessor()

# Read user ID from input.
user_id = input()
# Read item information from input.
item_count = int(input())
items = []
for _ in range(item_count):
    price, quantity = map(int, input().split())
    items.append({"price": price, "quantity": quantity})

processor.process_order(user_id, items)
