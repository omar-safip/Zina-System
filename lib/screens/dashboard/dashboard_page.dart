import 'package:flutter/material.dart';
import '../../widgets/sidebar.dart';
import '../../widgets/stat_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        drawer: const Drawer(child: Sidebar()),
        body: Column(
          children: [
            _buildTopBar(),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'لوحة التحكم',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'نظرة عامة على أداء النظام',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 24),

                    _buildStatistics(),

                    const SizedBox(height: 24),

                    _buildRecentSales(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Builder(
      builder: (context) {
        return Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
                icon: const Icon(Icons.menu, size: 27),
                tooltip: 'القائمة',
              ),

              const Spacer(),

              const Icon(Icons.notifications_none, size: 25),

              const SizedBox(width: 14),

              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue.shade50,
                child: const Icon(Icons.person, color: Color(0xFF1E4FA3)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatistics() {
    return GridView.count(
      crossAxisCount: 1,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        StatCard(
          title: 'إجمالي المبيعات',
          value: '0 ريال',
          icon: Icons.point_of_sale,
        ),

        StatCard(
          title: 'إجمالي الأرباح',
          value: '0 ريال',
          icon: Icons.trending_up,
        ),

        StatCard(title: 'عدد المسوقين', value: '0', icon: Icons.people_outline),

        StatCard(
          title: 'المنتجات',
          value: '0',
          icon: Icons.inventory_2_outlined,
        ),
      ],
    );
  }

  Widget _buildRecentSales() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'آخر عمليات البيع',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 50,
                    color: Colors.grey.shade400,
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'لا توجد عمليات بيع حتى الآن',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
