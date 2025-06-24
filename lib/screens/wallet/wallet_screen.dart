import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late Razorpay _razorpay;
  int _walletBalance = 0;
  int _lastPaymentAmount = 0;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadWalletBalance();
  }

  Future<void> _loadWalletBalance() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _walletBalance = prefs.getInt('wallet_balance') ?? 0;
    });
  }

  Future<void> _updateWalletBalance(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('wallet_balance', amount);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Payment Successful")),
    );
    setState(() {
      _walletBalance += _lastPaymentAmount;
    });
    _updateWalletBalance(_walletBalance);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Payment Failed")),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("External Wallet Selected")),
    );
  }

  void openCheckout() {
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text('Enter Deposit Amount', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Amount',
              hintStyle: TextStyle(color: Colors.white54),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () {
                final input = amountController.text.trim();
                final amount = int.tryParse(input);
                if (amount == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enter a numeric amount.")),
                  );
                  return;
                }
                if (amount < 500) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Amount must be at least ₹500.")),
                  );
                  return;
                }
                if (amount % 100 != 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Amount must be divisible by 100.")),
                  );
                  return;
                }

                _lastPaymentAmount = amount;

                Navigator.of(context).pop();

                var options = {
                  'key': dotenv.env['RAZORPAY_KEY'],
                  'amount': amount * 100,
                  'name': 'HeliKapter Wallet',
                  'description': 'Wallet Deposit',
                  'prefill': {
                    'contact': '9123456789',
                    'email': 'user@example.com',
                  },
                  'external': {
                    'wallets': ['paytm']
                  }
                };

                try {
                  _razorpay.open(options);
                  debugPrint("Razorpay checkout opened with options: $options");
                } catch (e, s) {
                  debugPrint('Razorpay checkout error: $e');
                  debugPrint('StackTrace: $s');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: ${e.toString()}")),
                  );
                }
              },
              child: const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("Building WalletScreen");
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Wallet Balance: ₹$_walletBalance',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 16),
            const Text(
              'Deposit Money',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: openCheckout,
              child: const Text('Deposit via Razorpay', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 32),
            const Text(
              'Withdraw Money',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                final TextEditingController amountController = TextEditingController();
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      backgroundColor: Colors.black,
                      title: const Text('Enter Withdrawal Amount', style: TextStyle(color: Colors.white)),
                      content: TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Amount',
                          hintStyle: TextStyle(color: Colors.white54),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                        ),
                        TextButton(
                          onPressed: () {
                            final input = amountController.text.trim();
                            final amount = int.tryParse(input);
                            if (amount == null || amount <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Please enter a valid positive amount.")),
                              );
                              return;
                            }
                            if (amount < 500) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Amount must be at least ₹500.")),
                              );
                              return;
                            }
                            if (amount % 100 != 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Amount must be divisible by 100.")),
                              );
                              return;
                            }
                            if (amount > _walletBalance) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Insufficient balance to withdraw.")),
                              );
                              return;
                            }
                            setState(() {
                              _walletBalance -= amount;
                            });
                            _updateWalletBalance(_walletBalance);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Withdrawal request of ₹$amount submitted.")),
                            );
                            Navigator.of(context).pop();
                          },
                          child: const Text('Submit', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    );
                  },
                );
              },
              child: const Text('Request Withdrawal', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
