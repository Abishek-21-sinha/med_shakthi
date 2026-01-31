import 'package:flutter/material.dart';

class SupplierPayoutPage extends StatelessWidget {
  const SupplierPayoutPage({super.key});

  final Color themeColor = const Color(0xFF4CA6A8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Payouts",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryCards(),
            const SizedBox(height: 20),
            _withdrawButton(context),
            const SizedBox(height: 24),
            _payoutHistory(),
          ],
        ),
      ),
    );
  }

  // ---------------- SUMMARY CARDS ----------------

  Widget _summaryCards() {
    return Row(
      children: [
        Expanded(
          child: _infoCard(
            title: "Total Earnings",
            amount: "₹ 1,24,500",
            icon: Icons.trending_up,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _infoCard(
            title: "Available Balance",
            amount: "₹ 32,800",
            icon: Icons.account_balance_wallet,
            color: themeColor,
          ),
        ),
      ],
    );
  }

  Widget _infoCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- WITHDRAW BUTTON ----------------

  Widget _withdrawButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Withdraw request sent")),
          );
        },
        icon: const Icon(Icons.account_balance),
        label: const Text(
          "Withdraw Balance",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: themeColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ---------------- PAYOUT HISTORY ----------------

  Widget _payoutHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Payout History",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _payoutTile(
          date: "12 Jan 2026",
          amount: "₹ 18,500",
          status: "Completed",
        ),
        _payoutTile(
          date: "05 Jan 2026",
          amount: "₹ 9,200",
          status: "Completed",
        ),
        _payoutTile(
          date: "28 Dec 2025",
          amount: "₹ 5,100",
          status: "Pending",
        ),
      ],
    );
  }

  Widget _payoutTile({
    required String date,
    required String amount,
    required String status,
  }) {
    final bool isCompleted = status == "Completed";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor:
            isCompleted ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
            child: Icon(
              isCompleted ? Icons.check_circle : Icons.schedule,
              color: isCompleted ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withOpacity(0.12)
                  : Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: isCompleted ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
