import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';
import '../providers/inventory_provider.dart';
import '../models/product.dart';
import '../services/printer_service.dart';
import 'pos/barcode_scanner_screen.dart';
import 'pos/sale_receipt_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نقطة البيع'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () async {
              final barcode = await Navigator.of(context).push<String>(
                MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
              );
              if (barcode != null) {
                _addProductByBarcode(barcode);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'ابحث عن منتج...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<InventoryProvider>().loadProducts();
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  context.read<InventoryProvider>().searchProducts(value);
                } else {
                  context.read<InventoryProvider>().loadProducts();
                }
              },
            ),
          ),

          // Products Grid
          Expanded(
            flex: 2,
            child: Consumer<InventoryProvider>(
              builder: (context, inventory, child) {
                if (inventory.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (inventory.products.isEmpty) {
                  return const Center(child: Text('لا توجد منتجات'));
                }
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: inventory.products.length,
                  itemBuilder: (context, index) {
                    final product = inventory.products[index];
                    return _ProductCard(
                      product: product,
                      onTap: () => _addToCart(product),
                    );
                  },
                );
              },
            ),
          ),

          // Cart Section
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Consumer<PosProvider>(
              builder: (context, pos, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pos.cartItems.isNotEmpty) ...[
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: pos.cartItems.length,
                          itemBuilder: (context, index) {
                            final item = pos.cartItems[index];
                            return ListTile(
                              dense: true,
                              title: Text(item.product.name, style: const TextStyle(fontSize: 14)),
                              subtitle: Text('${item.unitPrice.toStringAsFixed(2)} × ${item.quantity}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle, size: 20, color: Colors.red),
                                    onPressed: () => pos.updateQuantity(item.product.id!, item.quantity - 1),
                                  ),
                                  Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle, size: 20, color: Colors.green),
                                    onPressed: () => pos.updateQuantity(item.product.id!, item.quantity + 1),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(),
                    ],
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('المجموع:', style: TextStyle(fontSize: 16)),
                              Text(
                                '${pos.subtotal.toStringAsFixed(2)} د.ج',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (pos.discount > 0)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('الخصم:'),
                                Text('${pos.discount.toStringAsFixed(2)} د.ج', style: const TextStyle(color: Colors.red)),
                              ],
                            ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('الإجمالي:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text(
                                '${pos.total.toStringAsFixed(2)} د.ج',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E88E5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: pos.cartItems.isEmpty ? null : _showCheckoutDialog,
                                  icon: const Icon(Icons.payment),
                                  label: const Text('إتمام البيع'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF43A047),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: pos.cartItems.isEmpty ? null : () => pos.clearCart(),
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.red.withOpacity(0.1),
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _addToCart(Product product) {
    if (product.quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المنتج غير متوفر في المخزون')),
      );
      return;
    }
    context.read<PosProvider>().addToCart(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم إضافة ${product.name}')),
    );
  }

  Future<void> _addProductByBarcode(String barcode) async {
    final inventory = context.read<InventoryProvider>();
    final product = await inventory.getProductByBarcode(barcode);
    if (product != null) {
      _addToCart(product);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('المنتج غير موجود: $barcode')),
      );
    }
  }

  void _showCheckoutDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('إتمام البيع', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Consumer<PosProvider>(
                builder: (context, pos, child) {
                  return Column(
                    children: [
                      // Payment Method
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'cash', label: Text('نقداً'), icon: Icon(Icons.money)),
                          ButtonSegment(value: 'card', label: Text('بطاقة'), icon: Icon(Icons.credit_card)),
                          ButtonSegment(value: 'transfer', label: Text('تحويل'), icon: Icon(Icons.account_balance)),
                        ],
                        selected: {pos.paymentMethod},
                        onSelectionChanged: (selected) {
                          pos.setPaymentMethod(selected.first);
                        },
                      ),
                      const SizedBox(height: 16),
                      // Discount
                      TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'الخصم',
                          suffixText: 'د.ج',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          pos.setDiscount(double.tryParse(value) ?? 0);
                        },
                      ),
                      const SizedBox(height: 16),
                      // Total
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الإجمالي النهائي:', style: TextStyle(fontSize: 18)),
                            Text(
                              '${pos.total.toStringAsFixed(2)} د.ج',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E88E5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => _processCheckout(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF43A047),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('تأكيد البيع', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processCheckout(BuildContext dialogContext) async {
    final pos = context.read<PosProvider>();
    final sale = await pos.checkout();

    if (sale != null && mounted) {
      Navigator.of(dialogContext).pop();

      // Show receipt
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SaleReceiptScreen(sale: sale),
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إنشاء الفاتورة: ${sale.invoiceNumber}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLowStock = product.quantity <= product.minStock && product.minStock > 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isLowStock)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('نفاد', style: TextStyle(fontSize: 10, color: Colors.red)),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${product.quantity}', style: const TextStyle(fontSize: 10, color: Color(0xFF1E88E5))),
                  ),
                ],
              ),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${product.salePrice.toStringAsFixed(2)} د.ج',
                    style: const TextStyle(
                      color: Color(0xFF43A047),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.add_circle, color: Color(0xFF1E88E5)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
