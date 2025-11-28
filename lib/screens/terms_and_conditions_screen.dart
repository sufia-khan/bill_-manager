import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF97316),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFFF97316),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE5CC)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BillMinder Terms of Service',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Last updated: November 2024',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSection(
              '1. Acceptance of Terms',
              'By downloading, installing, or using BillMinder ("the App"), you agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use the App.',
            ),

            _buildSection(
              '2. Description of Service',
              'BillMinder is a personal finance management application designed to help users track and manage their bills, payments, and expenses. The App provides features including bill tracking, payment reminders, analytics, and cloud synchronization.',
            ),

            _buildSection(
              '3. User Accounts',
              '''• You must provide accurate and complete information when creating an account.
• You are responsible for maintaining the confidentiality of your account credentials.
• You are responsible for all activities that occur under your account.
• You must notify us immediately of any unauthorized use of your account.
• We reserve the right to suspend or terminate accounts that violate these terms.''',
            ),

            _buildSection('4. Acceptable Use', '''You agree NOT to:
• Use the App for any illegal or unauthorized purpose.
• Attempt to gain unauthorized access to our systems or other users' accounts.
• Interfere with or disrupt the App's functionality.
• Upload malicious code or content.
• Use the App to collect information about other users without their consent.
• Resell or redistribute the App without authorization.'''),

            _buildSection(
              '5. Intellectual Property',
              'All content, features, and functionality of the App, including but not limited to text, graphics, logos, icons, and software, are the exclusive property of BillMinder and are protected by international copyright, trademark, and other intellectual property laws.',
            ),

            _buildSection(
              '6. Subscription & Payments',
              '''• Some features of the App may require a paid subscription.
• Subscription fees are billed in advance on a monthly or annual basis.
• Refunds are handled according to the app store policies.
• We reserve the right to modify pricing with reasonable notice.
• Free trial periods may be offered at our discretion.''',
            ),

            _buildSection(
              '7. Data & Privacy',
              'Your use of the App is also governed by our Privacy Policy. By using the App, you consent to the collection and use of your data as described in our Privacy Policy.',
            ),

            _buildSection(
              '8. Disclaimer of Warranties',
              '''The App is provided "AS IS" and "AS AVAILABLE" without warranties of any kind.
• We do not guarantee that the App will be error-free or uninterrupted.
• We are not responsible for any financial decisions you make based on the App's information.
• The App is a tool for personal organization and should not be considered financial advice.''',
            ),

            _buildSection(
              '9. Limitation of Liability',
              'To the maximum extent permitted by law, BillMinder shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including but not limited to loss of profits, data, or goodwill arising from your use of the App.',
            ),

            _buildSection(
              '10. Account Termination',
              '''• You may delete your account at any time through the App settings.
• We may terminate or suspend your account for violations of these terms.
• Upon termination, your right to use the App will immediately cease.
• Some data may be retained as required by law or for legitimate business purposes.''',
            ),

            _buildSection(
              '11. Changes to Terms',
              'We reserve the right to modify these Terms at any time. We will notify users of significant changes through the App or via email. Your continued use of the App after such modifications constitutes acceptance of the updated Terms.',
            ),

            _buildSection(
              '12. Governing Law',
              'These Terms shall be governed by and construed in accordance with applicable laws, without regard to conflict of law principles.',
            ),

            _buildSection(
              '13. Contact Us',
              'If you have any questions about these Terms and Conditions, please contact us at:\n\nEmail: support@billminder.app',
            ),

            const SizedBox(height: 24),

            // Agreement Notice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF059669),
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'By using BillMinder, you acknowledge that you have read and agree to these Terms and Conditions.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
